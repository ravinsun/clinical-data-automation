 ********************************************************************
***  PROGRAM: cdisc_dataset_json.sas
***
***  AUTHOR: ra914800
***
***  DATE WRITTEN: 02/06/2026
***  Date Updated: 
***  Date Updated: 
***  DESCRIPTION:
***  - Check and list datasets in SDAT and export them as DATASET-JSON format to datatran/sdtmxpt
***
***  ASSUMPTIONS:
***  - None
***
***  INSTRUCTIONS FOR USER:
***  Place the program in progstat folder and run it   
***  
***  
***  INPUT:
***    datasdtm:
***
***  OUTPUT:
***    datatran/sdtmxpt:
***
***  MACROS:
***  INCLUDE CODE:
***  - None
***
***  FORMATS:
***  - inline
***
***  CHANGES:
***    Author:
***    Date:
***    Reason:
********************************************************************;

options  mlogic symbolgen nospool;
%macro cdisc_dataset_json(lib=);
/*Please UPDATE the below section for global macro variables*/

    %let dlabel = %sysfunc(compress(&DRUG_LABEL," "));

    %let project1 = %sysfunc(catx(/,&dlabel.,&INDICATION_LABEL.));
	%put &project1.;
	%let project = %lowcase(&project1.);
	%put &project.;

	%let study1    = %sysfunc(compress(&protocol_label,"-"));
	%let study = %lowcase(&study1.);
	%let folder   = dtc;

%let lib = %upcase(&lib);

proc sql noprint;
select memname into :dslist separated by ' '
from dictionary.tables
where libname = upcase("&lib")
and memtype = 'DATA';
quit;

%let n=%sysfunc(countw(&dslist));

%do i=1 %to &n;

%let ds=%scan(&dslist,&i);

/* ---- Variable metadata ---- */
proc contents data=&lib..&ds
out=_vars(keep=name label type length varnum) noprint;
run;

proc sort data=_vars; by varnum; run;

data items;
set _vars;
length OID $64 typejson $10;

OID = cats("IT.", "&ds.", name);

if type = 2 then typejson = "string";
else typejson = "integer";

keep OID name label typejson length;
rename typejson = type;
run;

/* ---- Data (records) ---- */
data itemData;
set &lib..&ds;
run;
%let ds = %LOWCASE(&ds);
%let outfile = %str(/ace/acedev/&project./&study./&folder./datatran/sdtmxpt/dataset-json/&ds..json);

filename js "&outfile.";

proc json out=js pretty nosastags;

write open object;
write values "clinicalData";
write open object;

/*write values "studyOID" "DUMMY-STUDY";*/
/*write values "metaDataVersionOID" "DUMMY-MDV";*/
/*write values "studyOID" "111-303";*/
/*write values "metaDataVersionOID" "MDV.MSGv2.0.SDTMIG.3.4.SDTM.2.0";*/

write values "itemGroupData";
write open object;

write values "IG.&ds";
write open object;

write values "records" %sysfunc(attrn(%sysfunc(open(&lib..&ds)),nobs));
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


%mend;
%cdisc_dataset_json(lib=sdat);
