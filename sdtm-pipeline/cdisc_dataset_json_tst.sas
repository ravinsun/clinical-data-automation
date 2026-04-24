/* Example sdat dm_test dataset */

data sdat.dm_test;
    attrib
        STUDYID label="Study Identifier" length=$12
        DOMAIN  label="Domain Abbreviation" length=$2
        USUBJID label="Unique Subject Identifier" length=$20
        AGE     label="Age" length=8
    ;
    input STUDYID $ DOMAIN $ USUBJID $ AGE;
    datalines;
ABC123 dm_test ABC123-001 56
ABC123 dm_test ABC123-002 63
;
run;

/* Add required Record Identifier (must be first variable in JSON items array) */
data dm_test_json;
    set sdat.dm_test;
    ITEMGROUPDATASEQ = _N_;
run;

proc contents data=dm_test_json out=varmeta(keep=name type length label varnum) 
              noprint varnum;
run;

/* Create JSON variable metadata */
data column_metadata;
    set varmeta;
    length OID $40 type_json $10 keySequence 8;
    
    /* Construct OID */
    if name = "ITEMGROUPDATASEQ" then 
        OID = "ITEMGROUPDATASEQ";
    else 
        OID = cats("IT.dm_test.", name);

    /* Map SAS type to Dataset-JSON type */
    if type = 2 then type_json = "string";
    else type_json = "integer";

    /* Optional keySequence example */
    if name in ("STUDYID","USUBJID") then keySequence = _N_;
run;

data column_data;
    set dm_test_json;
run;

%let studyOID = ABC123;
%let metaDataVersionOID = MDV.1.0;
%let fileOID = www.sponsor.com.ABC123.dm_test;
%let originator = Sponsor XYZ;
%let sourceSystem = SAS;
%let sourceSystemVersion = 9.4;
%let asOfDateTime = %sysfunc(datetime(), e8601dt.);

proc sql noprint;
    select count(*) into :tot_obs from dm_test_json;
quit;

filename outjson "/ace/acedev/bmn111/hch/111303/dtc/datatran/sdtmxpt/xpt-sasdataset/xpt-datasetjson/dm_test.json" encoding="utf-8";

proc json out=outjson pretty nofmtdatetime;
    write open object;

        /* --- Top Level Attributes --- */
        write values "creationDateTime" "%sysfunc(datetime(), e8601dt.)";
        write values "datasetJSONVersion" "1.0.0";
        write values "fileOID" "&fileOID";
        write values "asOfDateTime" "&asOfDateTime";
        write values "originator" "&originator";
        write values "sourceSystem" "&sourceSystem";
        write values "sourceSystemVersion" "&sourceSystemVersion";

        /* --- clinicalData --- */
        write values "clinicalData";
        write open object;

            write values "studyOID" "&studyOID";
            write values "metaDataVersionOID" "&metaDataVersionOID";

            /* --- itemGroupData --- */
            write values "itemGroupData";
            write open object;

                write values "IG.dm_test";
                write open object;

                    write values "records" &tot_obs;
                    write values "name" "dm_test";
                    write values "label" "Demographics";

                    /* --- items array --- */
                    write values "items";
                    write open array;
                        export column_metadata / nosastags;
                    write close;

                    /* --- itemData array --- */
                    write values "itemData";
                    write open array;
                        export column_data / nokeys nosastags;
                    write close;

                write close;
            write close;
        write close;
    write close;
run;
