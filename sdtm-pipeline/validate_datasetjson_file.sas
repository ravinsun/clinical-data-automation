
/*-------------------------------------------------------
 Validate Dataset-JSON file using SAS JSON engine
-------------------------------------------------------*/
options mlogic merror symbolgen;

%macro validate_json(jsonfile);

filename js "&jsonfile";

libname jslib json fileref=js;

%if &syslibrc ne 0 %then %do;
    %put ERRR: Invalid JSON file -> &jsonfile;
%end;
%else %do;
    proc datasets lib=jslib nolist;
    quit;

    %put NOTE: JSON file is valid -> &jsonfile;
%end;

libname jslib clear;
filename js clear;

%mend;

/* Example */
%validate_json(/ace/acedev/bmn111/hch/111303/dtc/datatran/sdtmxpt/PharmaSUG-336/datasetjson/AE.json);

/*SAS Program to Detect Invalid Numeric Values*/


data check_json;
infile "/ace/acedev/bmn111/hch/111303/dtc/datatran/sdtmxpt/datastep/dataset-json/AE.json" lrecl=32767 truncover;
input line $char32767.;

if prxmatch('/NaN|Inf|\.A|\.B|\.C|\.Z/', line) then
    put "WRNING: Invalid numeric literal found -> " line;
run;

/*SAS Program to Fix Invalid Values Automatically*/

data _null_;
infile "/ace/acedev/bmn111/hch/111303/dtc/datatran/sdtmxpt/datastep/dataset-json/AE.json" lrecl=32767 truncover;
file "/ace/acedev/bmn111/hch/111303/dtc/datatran/sdtmxpt/datastep/dataset-json/AE_clean.json";

input line $char32767.;

/* Replace invalid values with null */
line = tranwrd(line,'NaN','null');
line = tranwrd(line,'Inf','null');
line = tranwrd(line,'.A','null');
line = tranwrd(line,'.B','null');
line = tranwrd(line,'.C','null');
line = tranwrd(line,'.Z','null');

put line;
run;
