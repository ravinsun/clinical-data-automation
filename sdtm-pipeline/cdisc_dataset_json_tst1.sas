options merror mlogic symbolgen;
/*====================================================*/
/* Macro 1: Write One Dataset */
/*====================================================*/
%macro write_one_datasetjson(
        lib=,
        mem=,
        outdir=,
        studyOID=,
        metaDataVersionOID=
);

%put NOTE: ---- Processing &lib..&mem ----;

/* Add ITEMGROUPDATASEQ */
data _tmp_ds;
    set &lib..&mem;
    ITEMGROUPDATASEQ = _N_;
run;

/* Count records */
proc sql noprint;
    select count(*) into :tot_obs trimmed from _tmp_ds;
quit;

/* Extract metadata */
proc contents data=_tmp_ds
    out=_varmeta(keep=name type length label varnum)
    noprint varnum;
run;

/* Build JSON metadata */
data _column_metadata;
    set _varmeta(rename=(type=sas_type));
    length OID $60 type $10;

    if name = "ITEMGROUPDATASEQ" then
        OID = "ITEMGROUPDATASEQ";
    else
        OID = cats("IT.", upcase("&mem"), ".", name);

    if sas_type = 2 then type = "string";
    else type = "integer";

    drop sas_type;
run;

/* Write JSON */
filename outjson "&outdir./&mem..json" encoding="utf-8";

proc json out=outjson pretty nofmtdatetime;
    write open object;

        write values "creationDateTime" "%sysfunc(datetime(), e8601dt.)";
        write values "datasetJSONVersion" "1.0.0";

        write values "clinicalData";
        write open object;

            write values "studyOID" "&studyOID";
            write values "metaDataVersionOID" "&metaDataVersionOID";

            write values "itemGroupData";
            write open object;

                write values "IG.&mem";
                write open object;

                    write values "records" &tot_obs;
                    write values "name" "&mem";
                    write values "label" "&mem";

                    write values "items";
                    write open array;
                        export _column_metadata / nosastags;
                    write close;

                    write values "itemData";
                    write open array;
                        export _tmp_ds / nokeys nosastags;
                    write close;

                write close;
            write close;
        write close;
    write close;
run;

/* Cleanup */
proc datasets lib=work nolist;
    delete _tmp_ds _column_metadata _varmeta;
quit;

%mend write_one_datasetjson;


/*====================================================*/
/* Macro 2: Loop Library */
/*====================================================*/
%macro write_library_datasetjson(
        lib=,
        outdir=,
        studyOID=,
        metaDataVersionOID=
);

%if %sysfunc(libref(&lib)) ne 0 %then %do;
    %put ERRR: Library &lib is not assigned.;
    %return;
%end;

/* Get dataset list */
proc sql noprint;
    select memname
    into :dslist separated by ' '
    from dictionary.tables
    where upcase(libname)=upcase("&lib")
          and memtype='DATA';
quit;

%put NOTE: Datasets found: &dslist;

%let count = %sysfunc(countw(&dslist));

%if &count = 0 %then %do;
    %put WRNING: No datasets found in &lib..;
    %return;
%end;

/* Loop */
%do i=1 %to &count;
    %let ds = %scan(&dslist,&i);

    %write_one_datasetjson(
        lib=&lib,
        mem=&ds,
        outdir=&outdir,
        studyOID=&studyOID,
        metaDataVersionOID=&metaDataVersionOID
    );
%end;

%mend write_library_datasetjson;


%write_library_datasetjson(
    lib=sdat,
    outdir=/ace/acedev/bmn111/hch/111303/dtc/datatran/sdtmxpt/xpt-sasdataset/xpt-datasetjson/test,
    studyOID=111303,
    metaDataVersionOID=MDV.1.0
);


