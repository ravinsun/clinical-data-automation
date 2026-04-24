
%macro convert_xpt(inpath=, outpath=);
/*datasets stored path*/
libname outlib "&outpath";
/*xport files stored path*/
filename xptdir "&inpath";

data xpt_list;
length fname $256;
did = dopen("xptdir");
if did > 0 then do i = 1 to dnum(did);
fname = dread(did,i);
if lowcase(scan(fname,-1,'.')) = 'xpt' then output;
end;
rc = dclose(did);
drop did i rc;
run;

data _null_;
set xpt_list;
call execute(cats('
libname xptlib xport "', "&inpath/", fname, '";
proc copy in=xptlib out=outlib memtype=data; run;
libname xptlib clear;
'));
run;

%mend;

/* Macro Invocation */
%convert_xpt(
inpath=/ace/acedev/bmn111/hch/111303/dtc/datatran/sdtmxpt/xpt-sasdataset,
outpath=/ace/acedev/bmn111/hch/111303/dtc/datatran/sdtmxpt/xpt-sasdataset/dataset);
