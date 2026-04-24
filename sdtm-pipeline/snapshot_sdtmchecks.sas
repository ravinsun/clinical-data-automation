********************************************************************
***  PROGRAM: snapshot_sdtmchecks.sas
***
***  AUTHOR: ra914800
***
***  DATE WRITTEN: 12/01/2025
***  Modified Date: 01/27/2026
***  DESCRIPTION:
***  - Read v_rd_study_snapshot_filtering program and extract macros
***
***  ASSUMPTIONS:
***  - None
***
***  INSTRUCTIONS FOR USER:
***  - 
***
***  INPUT:
***    v_rd_study_snapshot_filtering.sas
***
***  OUTPUT:
***    SAS Macros: folder type datacut snapshot
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

/**********************************************************************
Extracts only simple %LET name = value; statements.
**********************************************************************/

options nosymbolgen nomprint nomlogic;

/*%macro read_saspgm_extract_macro(source_file=,picklist_raw=);*/
%macro read_saspgm_extract_macro(picklist_raw=);
dm 'log;clear;';run;

%global project study folder type datacut snapshot source prod file;


/*Please UPDATE the below section for global macro variables*/
    %let dlabel = %sysfunc(compress(&DRUG_LABEL," "));
    %let project1 = %sysfunc(catx(/,&dlabel.,&INDICATION_LABEL.));
	%put &project1.;
	%let project = %lowcase(&project1.);
	%put &project.;
	%let study1    = %sysfunc(compress(&protocol_label,"-"));
	%let study = %lowcase(&study1.);
	%let folder   = dtc;

%let source = %str(../../&folder./progstat);
%let dev    = %str(../../&folder./progstat);
%let source_file   = %str(/ace/acever/&project./&study./&folder./progstat/v_rd_study_snapshot_filtering.sas);

libname indat "&source";
libname prod  "&dev";

/*---------------------------------------------------------------
Picklist of allowed macro variables (CASE INSENSITIVE)
----------------------------------------------------------------*/
/* RAW picklist (user-provided) */
%let picklist_raw =&picklist_raw.;

/* Clean picklist: FIX hidden chars, normalize case, compress spaces */
%let picklist = %sysfunc(compbl(%superq(picklist_raw)));
%let picklist = %upcase(&picklist);

/* Debug print of final clean picklist */
%put NOTE: CLEAN PICKLIST = >>>&picklist<<<;
%put NOTE: PICKLIST LENGTH = %length(&picklist);


/**********************************************************************
Extraction logic
**********************************************************************/
data extracted_macros;
infile "&source_file" lrecl=4000 truncover;
length line clean name value $500;
retain re;

if _n_ = 1 then do;
/* regex: %let name = value ; (simple only) */
re = prxparse('/^\s*%let\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*;/i');
call missing(name,value);
end;

input line $char4000.;
clean = strip(line);

/* Debug */
put "DEBUG: LINE -> |" clean "|";

/* Skip empty lines */
if clean = "" then return;

/* Skip %let lines with macro functions (%sysfunc, %eval, %substr etc) */
if prxmatch('/%\w+\s*\(/i', clean) then do;
put "DEBUG: SKIPPED (function) -> " clean;
return;
end;

/* If not a simple %let pattern, skip */
if prxmatch(re, clean) then do;

/* Extract name */
call prxposn(re, 1, sp, ln);
if sp>0 then name = upcase(strip(substr(clean, sp, ln)));

/* Check against picklist */
if indexw("&picklist", name, ' ') = 0 then do;
put "DEBUG: SKIPPED (not in picklist) -> name=" name;
return;
end;

/* Extract value */
call prxposn(re, 2, sp2, ln2);
if sp2>0 then value = strip(substr(clean, sp2, ln2));

/* Debug */
put "DEBUG: FOUND name=" name " value=" value;

/* Output dataset */
output;

/* Create global macro var */
call symputx(name, value, 'G');

end;
run;


/**********************************************************************
Display extracted macro variables
**********************************************************************/
title "Extracted Macro Variables (Picklist Only)";
proc print data=extracted_macros; run;

%mend read_saspgm_extract_macro;

%read_saspgm_extract_macro(picklist_raw=folder type datacut snapshot);

%put NOTE: VALUE OF FOLDER = &FOLDER;
%put NOTE: VALUE OF TYPE = &TYPE;
%put NOTE: VALUE OF DATACUT = &DATACUT;
%put NOTE: VALUE OF SNAPSHOT = &SNAPSHOT;


