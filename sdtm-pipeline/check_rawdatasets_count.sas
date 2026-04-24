 ********************************************************************
***  PROGRAM: check_rawdatasets
***
***  AUTHOR: ra914800
***
***  DATE WRITTEN: 11/07/2025
***  Date Updated: 01/13/2026
***  Date Updated: 01/15/2026
***  Date Updated: 03/17/2026
***  Added obs_count adjacent to dataset name 
***  DESCRIPTION:
***  - Compare datasets in dataoper and dataraw path and identify the programs use these datasets
***
***  ASSUMPTIONS:
***  - None
***
***  INSTRUCTIONS FOR USER:
***  Place the program in progstat folder and run it   
***  
***  
***  INPUT:
***    datasdtm:odat and rdat
***
***  OUTPUT:
***    datasdtm:
***    library_usage_summary.pdf
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


%macro check_library_usage;

/*Please UPDATE the below section for global macro variables*/
    %let dlabel = %sysfunc(compress(&DRUG_LABEL," "));

    %let project1 = %sysfunc(catx(/,&dlabel.,&INDICATION_LABEL.));
	%put &project1.;
	%let project = %lowcase(&project1.);
	%put &project.;

	%let study    = %sysfunc(compress(&protocol_label,"-"));
	%let folder   = dtc;

	%let path    = %str(/ace/acedev/&project./&study./&folder./progstat);
	%let run_dt = %sysfunc(today(),yymmdd10.);
	%let source_file   = %str(/ace/acedev/&project./&study./&folder./documentation/specs/library_usage_summary_&run_dt..pdf);


/*----------------------------------------------------
Step 1 Capture all datasets from the specified library
----------------------------------------------------*/
	proc sql;
		create table work._raw_datasets as
		select upcase(libname) as libname,
		upcase(memname) as dataset_name,
		nobs as obs_count
	
		from dictionary.tables
		where libname = "RDAT"
		and memtype = 'DATA';
	quit;

	%put NOTE: Found %sysfunc(attrn(%sysfunc(open(work._raw_datasets)),NOBS)) datasets in RDAT library.;

	proc print data=_raw_datasets;
	run;

/*	Get the dataset names from the ODAT library*/
	data odat_list(keep=libname memname);
	    set sashelp.vtable;
	    where libname = 'ODAT' and memtype='DATA';
	run;

/*	Get the dataset names from the RDAT library*/
	data rdat_list(keep=libname memname);
	    set sashelp.vtable;
	    where libname = 'RDAT' and memtype='DATA';
	run;

/*Sort both odat and rdat lists by dataset name*/
	proc sort data=odat_list; by memname; run;
	proc sort data=rdat_list; by memname; run;


/*Compare odat and rdat datasets */
	data compare ;
		
	    merge odat_list(in=in1) rdat_list(in=in2);
	    by memname;

	    length status $40;
	    if in1 and not in2 then status='Only in dataoper path';
	    else if in2 and not in1 then status='Only in dataraw path';
	    else if in1 and in2 then status='Common to both dataoper and dataraw paths';

	    output;
	run;

	data compare1 (drop=libname);
		set compare;
	Run;


/*----------------------------------------------------
Step 2 Collect all SAS programs from UNIX directory
(FULL paths returned by FIND)
----------------------------------------------------*/
	filename pgms pipe "find &path -type f -name 'sd_*.sas'";

	data work._program_files;
		length fullpath $500;
		infile pgms truncover;
		input fullpath $500.;
	run;

/*----------------------------------------------------
Step 3 Read each SAS program line-by-line
----------------------------------------------------*/
	data work._program_code;
		set work._program_files;

		length filevar $500 line $1000;
		filevar = fullpath;

		infile dummy filevar=filevar truncover end=eof;
		do while (not eof);
		input line $char1000.;
		line = upcase(line);
		output;
		end;

		keep fullpath line;
	run;

/*----------------------------------------------------
Step 4  Identify datasets from the library referenced in code
----------------------------------------------------*/
	proc sql;
		create table work._dataset_usage as
		select distinct
		a.dataset_name,
		b.fullpath
		from work._raw_datasets a
		inner join work._program_code b
		on index(b.line, cats("RDAT.", a.dataset_name)) > 0
		order by a.dataset_name, b.fullpath;
	quit;

/*----------------------------------------------------
Step 5  Aggregate programs per dataset
----------------------------------------------------*/
	proc sort data=work._dataset_usage nodupkey;
		by dataset_name fullpath;
	run;

	data work._dataset_usage_summary;
		length used_in_programs $4000;
		retain used_in_programs program_count;

		set work._dataset_usage;
		by dataset_name;

		if first.dataset_name then do;
		used_in_programs = fullpath;
		program_count = 1;
		end;
		else do;
		used_in_programs = catx(', ', used_in_programs, fullpath);
		program_count + 1;
		end;

		if last.dataset_name then output;

		keep dataset_name used_in_programs program_count;
	run;

/*----------------------------------------------------
Step 6  Merge with full list to mark Used / Not Used
----------------------------------------------------*/
	data work.library_usage_summary;
		length dataset_name $32
		usage_status $10
		used_in_programs $4000
		program_count 8
		obs_count 8;

		merge work._raw_datasets (in=a)
		work._dataset_usage_summary (in=b);
		by dataset_name;

		if a;

		if b then usage_status = 'Used';
		else do;
		usage_status = 'Not Used';
		used_in_programs = '';
		program_count = 0;
		end;
	run;

	proc contents data=library_usage_summary;
	Run;

/*----------------------------------------------------
UNIX export
----------------------------------------------------*/
/* Open the ODS PDF destination */
	title;
	ods listing close;
	ods pdf file="&source_file" style=sasweb;
        title 'Datasets used in sas programs';
        ods proclabel"library_usage_summary ";
		    /* Output the first dataset  */
			proc report data=work.library_usage_summary nowd split='|';
			columns dataset_name obs_count usage_status used_in_programs program_count;

			define dataset_name / display "Dataset Name";
			define obs_count / display "Obs Count" format=comma12.;
			define usage_status / display "Usage Status";
			define used_in_programs / display "Used In Programs" flow;
			define program_count / display "Program count";

	    title 'Datasets present in dataoper and dataraw paths';
		ods proclabel "comparison"; 

			/* Output the second dataset  */
			proc print data=work.compare1;
			run;

	/* Close the ODS PDF destination */
	ods pdf close;
	ods listing;

%mend check_library_usage;

/*Invoking the macro with path where the SDTM sas programs are present*/
/*%check_library_usage(path=/ace/acedev/bmn111/hch/111303/dtc);*/
%check_library_usage;
