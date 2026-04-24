/*=========================================================
CDISC Dataset-JSON v1.1 Export Using PROC JSON
Input : All datasets in a SAS library
Output: One Dataset-JSON file per dataset
=========================================================*/

/* -------- USER SETTINGS -------- */
%let lib = sdat; /* Input library */
    %let dlabel = %sysfunc(compress(&DRUG_LABEL," "));

    %let project1 = %sysfunc(catx(/,&dlabel.,&INDICATION_LABEL.));
	%put &project1.;
	%let project = %lowcase(&project1.);
	%put &project.;

	%let study1    = %sysfunc(compress(&protocol_label,"-"));
	%let study = %lowcase(&study1.);
	%let folder   = dtc;

%let lib = %upcase(&lib);
%let outpath = /ace/acedev/&project./&study./&folder./datatran/sdtmxpt/PharmaSUG-336/datasetjson;
%let studyOID = 111-303;
%let metaDataVersionOID = MDV.MSGv2.0.SDTMIG.3.4.SDTM.2.0;

/*---------------------------------------------------------
Get dataset list from library
---------------------------------------------------------*/
proc sql noprint;
select memname, coalesce(memlabel,memname)
into :dslist separated by '|',
:labellist separated by '|'
from dictionary.tables
where libname = "%upcase(&lib)"
and memtype = 'DATA';
quit;

%let dscount = %sysfunc(countw(&dslist,|));


/*---------------------------------------------------------
Loop through datasets
---------------------------------------------------------*/
%macro export_all;

%do d = 1 %to &dscount;

%let dataset = %scan(&dslist,&d,|);
%let label = %scan(&labellist,&d,|);
%let domain = &dataset;
%let IGD = IG.&dataset;


/* ---- Record count ---- */
%let dsid = %sysfunc(open(&lib..&dataset));
%let nobs = %sysfunc(attrn(&dsid,nobs));
%let modate = %sysfunc(putn(%sysfunc(attrn(&dsid,modte)),E8601DT19.));
%let rc = %sysfunc(close(&dsid));

%let start_time = %sysfunc(datetime(),E8601DT19.);


/*------------------------------------------------------
Build COLUMN METADATA
------------------------------------------------------*/
proc contents data=&lib..&dataset
out=work.&dataset._contents(keep=name label type length varnum)
noprint;
run;

proc sort data=work.&dataset._contents; by varnum; run;

data work.&dataset._contents;
set work.&dataset._contents;
length itemOID $64 dataType $12;

itemOID = cats("IT.", "&dataset.", name);

if type = 2 then dataType = "string";
else dataType = "float";

keep itemOID name label dataType length;
run;


/*------------------------------------------------------
Write Dataset-JSON file
------------------------------------------------------*/
filename js "&outpath/&dataset..json" encoding='utf-8';

proc json out=js pretty nosastags;

write open object;

write values "datasetJSONCreationDateTime" "&start_time";
/*write values "datasetJSONVersion" "1.1.0";*/
/*write values "fileOID" "www.sponsor.xyz.org.project123.final";*/
/*write values "dbLastModifiedDateTime" "&modate";*/
/*write values "originator" "Sponsor XYZ";*/

write values "sourceSystem";
write open object;
write values "originator" "SAS";
write values "sourceSystem" "&sysvlong";
write close;

write values "studyOID" "&studyOID";
write values "metaDataVersionOID" "&metaDataVersionOID";
/*write values "metaDataRef" "https://metadata.location.org/api.link";*/

write values "itemGroupOID" "&IGD";
write values "isReferenceData" false;

write values "records" &nobs;
write values "name" "&domain";
write values "label" "&label";

/* ---- columns ---- */
write values "columns";
write open array;
export work.&dataset._contents / keys nosastags;
write close;

/* ---- rows ---- */
write values "rows";
write open array;
export &lib..&dataset / nokeys nosastags trimblanks;
write close;

write close;

run;

filename js clear;

%end;

%mend;

%export_all;
