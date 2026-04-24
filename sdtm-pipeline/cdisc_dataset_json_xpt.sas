options mlogic symbolgen nospool;

%macro cdisc_dataset_json();


    %let dlabel = %sysfunc(compress(&DRUG_LABEL," "));

    %let project1 = %sysfunc(catx(/,&dlabel.,&INDICATION_LABEL.));
	%put &project1.;
	%let project = %lowcase(&project1.);
	%put &project.;

	%let study1    = %sysfunc(compress(&protocol_label,"-"));
	%let study = %lowcase(&study1.);
	%let folder   = dtc;

%let xptpath = %str(/ace/acedev/&project./&study./&folder./datatran/sdtmxpt);
/*---------------------------------------------------------
STEP 1: Get list of XPT files in folder
---------------------------------------------------------*/
filename xdir pipe "ls &xptpath/*.xpt";

data _xptfiles;
length fullpath $300;
infile xdir truncover;
input fullpath $300.;
run;


/*---------------------------------------------------------
STEP 2: Loop through each XPT file
---------------------------------------------------------*/
data _null_;
set _xptfiles;
call execute(cats('%nrstr(%process_xpt)(',quote(trim(fullpath)),');'));
run;

%mend;


/*=========================================================
Process single XPT (Core logic mostly unchanged)
=========================================================*/
%macro process_xpt(fullpath);

/* Assign XPORT file */
libname inxpt xport "&xptpath" access=readonly;


/* Get dataset inside XPT */
proc sql noprint;
select memname into :dslist separated by ' '
from dictionary.tables
where libname = 'INXPT'
and memtype = 'DATA';
quit;

%let n=%sysfunc(countw(&dslist));


%do i=1 %to &n;

%let ds=%scan(&dslist,&i);


/* ---- Variable metadata (UNCHANGED) ---- */
proc contents data=inxpt.&ds
out=_vars(keep=name label type length varnum) noprint;
run;

proc sort data=_vars; by varnum; run;


/* ---- Column metadata (UNCHANGED) ---- */
data items;
set _vars;
length OID $64 typejson $10;

OID = cats("IT.", "&ds.", name);

if type = 2 then typejson = "string";
else typejson = "integer";

keep OID name label typejson length;
rename typejson = type;
run;


/* ---- Data (UNCHANGED) ---- */
data itemData;
set inxpt.&ds;
run;


/* ---- Record count ---- */
%let dsid = %sysfunc(open(inxpt.&ds));
%let nobs = %sysfunc(attrn(&dsid,nobs));
%let rc = %sysfunc(close(&dsid));


/* ---- Output file ---- */
%let outfile = &xptpath/xpt-datasetjson/&ds..json;
filename js "&outfile.";


/* ---- PROC JSON (UNCHANGED STRUCTURE) ---- */
proc json out=js pretty nosastags;

write open object;

write values "clinicalData";
write open object;

write values "itemGroupData";
write open object;

write values "IG.&ds";
write open object;

write values "records" &nobs;
write values "name" "&ds";
write values "label" "&ds Dataset";

write values "items";
write open array;
export items / keys;
write close;

write values "itemData";
write open array;
export itemData / nokeys;
write close;

write close; /* IG */
write close; /* itemGroupData */
write close; /* clinicalData */
write close;

run;

%end;

/* Clear XPORT library */
libname inxpt clear;

%mend;

%cdisc_dataset_json();

