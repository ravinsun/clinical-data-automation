%macro xpt_to_datasetjson(inpath=, outpath=);

%local filrf rc did memcnt i fname dsname dslbl;

%let filrf=mydir;
%let rc=%sysfunc(filename(filrf,&inpath));
%let did=%sysfunc(dopen(&filrf));

%if &did = 0 %then %do;
%put ERRR: Cannot open input directory.;
%return;
%end;

%let memcnt=%sysfunc(dnum(&did));

%do i=1 %to &memcnt;

%let fname=%sysfunc(dread(&did,&i));

%if "%upcase(%scan(&fname,-1,.))" = "XPT" %then %do;

%let dsname=%scan(&fname,1,.);

%put NOTE: Processing &fname ...;

libname xptlib xport "&inpath/&fname" access=readonly;

/* Extract metadata correctly */
proc contents data=xptlib.&dsname
out=_meta(keep=name label varnum memlabel)
noprint;
run;

proc sort data=_meta; by varnum; run;

/* Capture dataset label */
proc sql noprint;
select distinct memlabel into :dslbl trimmed from _meta;
quit;

%if "&dslbl" = "" %then %let dslbl=&dsname;

/* Create column structure dataset */
data _columns;
set _meta;
keep name label;
run;

filename outjson "&outpath/&dsname..json" encoding='utf-8';

proc json out=outjson pretty nosastags;

write open object;

write values "clinicalData";
write open object;

write values "datasets";
write open array;

write open object;

write values "name" "&dsname";
write values "label" "&dslbl";

/* Columns */
write values "columns";
write open array;
export _columns;
write close;

/* Rows */
write values "rows";
write open array;
export xptlib.&dsname;
write close;

write close;

write close;

write close;

write close;

run;

libname xptlib clear;

%put NOTE: Finished &dsname..json;

%end;

%end;

%let rc=%sysfunc(dclose(&did));
%let rc=%sysfunc(filename(filrf));

%mend;





%xpt_to_datasetjson(
    inpath=/ace/acedev/bmn111/hch/111303/dtc/datatran/sdtmxpt,
    outpath=/ace/acedev/bmn111/hch/111303/dtc/datatran/sdtmxpt/xpt-datasetjson
);
