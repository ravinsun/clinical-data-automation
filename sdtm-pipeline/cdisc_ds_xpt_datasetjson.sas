/*=========================================================
 CDISC Dataset-JSON Export Utility
 Stable / Clean Log / No Truncation
=========================================================*/


options mlogic symbolgen;

/*---- Folder containing XPT files ----*/
%let xptpath = /ace/acedev/bmn111/hch/111303/dtc/datatran/sdtmxpt;

/*---- Output JSON folder ----*/
%let outpath = /ace/acedev/bmn111/hch/111303/dtc/datatran/sdtmxpt/datastep/xpt-json;


/*---------------------------------------------------------
Get list of XPT files from folder
---------------------------------------------------------*/
filename xdir "&xptpath";

data xptfiles;
length fname $256 fullpath $500;
did=dopen('xdir');

do i=1 to dnum(did);
fname=dread(did,i);

if lowcase(scan(fname,-1,'.'))='xpt' then do;
fullpath=cats("&xptpath/",fname);
output;
end;
end;

rc=dclose(did);
run;


/*---------------------------------------------------------
Macro to process one XPT file
---------------------------------------------------------*/
%macro process_xpt(xptfile);

%put NOTE: Processing &xptfile;

/* assign XPORT engine */
libname xptlib xport "&xptfile";

/* use existing logic */
%let lib = xptlib;


/*---------------------------------------------------------
Get dataset list
---------------------------------------------------------*/
proc sql noprint;
select memname, coalesce(memlabel,memname)
into :dslist separated by '|',
:labellist separated by '|'
from dictionary.tables
where libname="%upcase(&lib)"
and memtype='DATA';
quit;

%let dscount=%sysfunc(countw(&dslist,|));


/*---------------------------------------------------------
Export entire library
---------------------------------------------------------*/
%macro export_library;

%do d=1 %to &dscount;

%let mem=%scan(&dslist,&d,|);
%let label=%scan(&labellist,&d,|);

%export_one;

%end;

%mend;


/*---------------------------------------------------------
Export one dataset
---------------------------------------------------------*/
%macro export_one;

proc sql noprint;
create table _meta as
select name,
type,
length,
varnum,
upcase(coalesce(format,'')) as fmt
from dictionary.columns
where libname="%upcase(&lib)"
and memname="%upcase(&mem)"
order by varnum;

select count(*) into :nobs trimmed
from &lib..&mem;
quit;


/*---------------- JSON OUTPUT FILE ----------------*/
filename dj "&outpath/&mem..json" encoding='utf-8';


/*---------------- HEADER + COLUMNS ----------------*/
data _null_;
set _meta end=eof;
file dj lrecl=32767 encoding='utf-8';

length dsname $32 dslabel $256;

dsname="&mem";
dslabel="&label";

if _n_=1 then do;

put '{';
put '"datasetJSONVersion":"1.1.0",';
put '"name":"' dsname +(-1) '",';
put '"label":"' dslabel +(-1) '",';
put '"records":' "&nobs" +(-1) ',';
put '"columns":[';

end;

put '{';
put '"itemOID":"IT.' dsname +(-1) '.' name +(-1) '",';
put '"name":"' name +(-1) '",';

if type='char' then do;
put '"dataType":"string",';
put '"length":' length;
end;
else do;

if index(fmt,'DATETIME') then
put '"dataType":"datetime"';
else if index(fmt,'DATE') then
put '"dataType":"date"';
else if index(fmt,'TIME') then
put '"dataType":"time"';
else
put '"dataType":"float"';

end;

put '}';

if not eof then put ',';
else do;
put '],';
put '"rows":[';
end;

run;


/*---------------- ROWS ----------------*/
/* Get variable counts */
proc sql noprint;
select sum(type='char'), sum(type='num')
into :nchar, :nnum
from dictionary.columns
where libname="%upcase(&lib)"
and memname="%upcase(&mem)";
quit;


data _null_;

set &lib..&mem end=eof;
file dj mod;

length line $32767 cell $32767;

line='[';

/* character variables */
%if &nchar > 0 %then %do;

array _c {*} _character_;

do i=1 to dim(_c);

if missing(_c[i]) then cell='null';
else cell=cats('"',tranwrd(_c[i],'"','\"'),'"');

if i=1 then line=cats(line,cell);
else line=cats(line,',',cell);

end;

%end;


/* numeric variables */
%if &nnum > 0 %then %do;

array _n {*} _numeric_;

do j=1 to dim(_n);

if missing(_n[j]) then cell='null';
else cell=strip(put(_n[j],best32.));

if &nchar>0 or j>1 then
line=cats(line,',',cell);
else
line=cats(line,cell);

end;

%end;

line=cats(line,']');

if not eof then put line ',';
else do;
put line;
put ']';
put '}';
end;

run;




filename dj clear;

%mend;


/* run export */
%export_library;


/* clear library */
libname xptlib clear;

%mend;


/*---------------------------------------------------------
Process all XPT files
---------------------------------------------------------*/
data _null_;
set xptfiles;
call execute(cats('%nrstr(%process_xpt)(',fullpath,');'));
run;

