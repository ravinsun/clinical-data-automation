/*==============================================================================
  SDTM DOMAIN: DM — Demographics
  ------------------------------------------------------------------------------
  Standard : CDISC SDTM IG v3.3
  Domain   : DM (Special Purpose — one record per subject)
  Study    : SAMPLE001 (Synthetic data — no real patient information)
  Author   : Ravinder Maramamula
  Created  : 2025

  Description:
    Derives the DM SDTM domain from raw demographics CRF data.
    Handles age derivation, race/ethnicity mapping, RFSTDTC/RFENDTC
    assignment, and ACTARM/PLANNED ARM population flags.

  Inputs  : RAWDATA.DM_RAW  (synthetic raw demographics)
  Outputs : SDTMDATA.DM
==============================================================================*/


/*==============================================================================
  MACRO: %create_raw_dm
  Creates synthetic raw demographics data for demonstration purposes.
==============================================================================*/
%macro create_raw_dm();

  data rawdata.dm_raw;
    infile datalines delimiter=',' dsd truncover;
    input
      subjectid   : $20.
      siteid      : $10.
      arm         : $50.
      sex         : $1.
      race        : $100.
      ethnic      : $50.
      birthdt     : $10.
      icfdt       : $10.
      firstdosedt : $10.
      lastdosedt  : $10.
      enrlflag    : $1.
      complfl     : $1.
      country     : $3.
    ;
  datalines;
SAMPLE001-001-0001,001,TREATMENT A,M,WHITE,NOT HISPANIC OR LATINO,1978-04-15,2023-01-10,2023-01-17,2023-07-17,Y,Y,USA
SAMPLE001-001-0002,001,TREATMENT B,F,BLACK OR AFRICAN AMERICAN,NOT HISPANIC OR LATINO,1985-09-22,2023-01-12,2023-01-19,2023-07-19,Y,Y,USA
SAMPLE001-002-0003,002,TREATMENT A,F,WHITE,HISPANIC OR LATINO,1990-03-08,2023-01-15,2023-01-22,2023-07-22,Y,N,USA
SAMPLE001-002-0004,002,PLACEBO,M,ASIAN,NOT HISPANIC OR LATINO,1972-11-30,2023-01-18,2023-01-25,2023-04-25,Y,N,USA
SAMPLE001-003-0005,003,TREATMENT B,M,WHITE,NOT HISPANIC OR LATINO,1968-07-19,2023-01-20,2023-01-27,2023-07-27,Y,Y,USA
SAMPLE001-003-0006,003,PLACEBO,F,WHITE,NOT HISPANIC OR LATINO,1995-02-14,2023-01-22,2023-01-29,2023-07-29,Y,Y,USA
SAMPLE001-004-0007,004,TREATMENT A,M,AMERICAN INDIAN OR ALASKA NATIVE,NOT HISPANIC OR LATINO,1980-06-25,2023-01-25,2023-02-01,2023-08-01,Y,Y,USA
SAMPLE001-004-0008,004,TREATMENT B,F,WHITE,NOT HISPANIC OR LATINO,1975-12-03,2023-01-28,2023-02-04,2023-08-04,Y,Y,USA
  ;
  run;

  %put NOTE: [create_raw_dm] Synthetic raw DM data created — &sysnobs. records.;

%mend create_raw_dm;


/*==============================================================================
  MACRO: %derive_dm
  Derives SDTM DM domain from raw demographics data.

  Key derivations:
    - USUBJID  : Unique Subject Identifier (STUDYID-SITEID-SUBJID)
    - AGE      : Age at informed consent (years, from BRTHDTC to RFICDTC)
    - AGEU     : Age units (YEARS)
    - RFSTDTC  : Reference Start Date (first dose date)
    - RFENDTC  : Reference End Date (last dose date)
    - RFICDTC  : Informed Consent Date
    - ACTARM   : Actual Treatment Arm
    - ACTARMCD : Actual Arm Code
    - ARMNRS   : Reason not randomised (if applicable)
    - DMDTC    : Date of demographics collection
    - DMDY     : Study day of demographics collection
==============================================================================*/
%macro derive_dm(
  inds    = rawdata.dm_raw,
  outds   = sdtmdata.dm,
  studyid = SAMPLE001
);

  %put ── [derive_dm] Deriving DM domain from &inds.;

  data &outds.;
    set &inds.;

    length
      STUDYID  $12
      DOMAIN   $2
      USUBJID  $50
      SUBJID   $20
      SITEID   $10
      INVID    $10
      INVNAM   $100
      BRTHDTC  $10
      AGE       8
      AGEU     $6
      SEX      $1
      RACE     $200
      ETHNIC   $200
      ARMCD    $20
      ARM      $200
      ACTARMCD $20
      ACTARM   $200
      COUNTRY  $3
      DMDTC    $10
      DMDY      8
      RFICDTC  $10
      RFSTDTC  $10
      RFENDTC  $10
      RFXSTDTC $10
      RFXENDTC $10
      RFPENDTC $10
      DTHDTC   $10
      DTHFL    $1
    ;

    /* ── Fixed study-level variables ─────────────────────────────── */
    STUDYID = "&studyid.";
    DOMAIN  = "DM";

    /* ── Subject identifiers ─────────────────────────────────────── */
    SUBJID  = strip(subjectid);
    SITEID  = strip(siteid);
    USUBJID = catx('-', strip(STUDYID), strip(SITEID),
                   scan(strip(subjectid), -1, '-'));

    /* ── Dates ───────────────────────────────────────────────────── */
    BRTHDTC  = strip(birthdt);
    RFICDTC  = strip(icfdt);
    RFSTDTC  = strip(firstdosedt);
    RFENDTC  = strip(lastdosedt);
    RFXSTDTC = strip(firstdosedt);   /* first exposure = first dose */
    RFXENDTC = strip(lastdosedt);    /* last exposure  = last dose  */

    /* ── Age derivation — years from BRTHDTC to RFICDTC ─────────── */
    if strip(birthdt) ne '' and strip(icfdt) ne '' then do;
      _bdt = input(strip(birthdt), yymmdd10.);
      _idt = input(strip(icfdt),   yymmdd10.);
      if nmiss(_bdt, _idt) = 0 then do;
        AGE  = floor((_idt - _bdt) / 365.25);
        AGEU = 'YEARS';
      end;
    end;

    /* ── Demographics ────────────────────────────────────────────── */
    SEX    = upcase(strip(sex));
    RACE   = upcase(strip(race));
    ETHNIC = upcase(strip(ethnic));

    /* ── Arm assignment ──────────────────────────────────────────── */
    ACTARM = upcase(strip(arm));
    select (ACTARM);
      when ('TREATMENT A') do; ACTARMCD = 'TRTА'; ARM = ACTARM; ARMCD = ACTARMCD; end;
      when ('TREATMENT B') do; ACTARMCD = 'TRTB'; ARM = ACTARM; ARMCD = ACTARMCD; end;
      when ('PLACEBO')     do; ACTARMCD = 'PBO';  ARM = ACTARM; ARMCD = ACTARMCD; end;
      otherwise do;
        ACTARMCD = 'SCRNFAIL';
        ARMCD    = 'SCRNFAIL';
        ARM      = 'Screen Failure';
      end;
    end;

    /* ── Country ─────────────────────────────────────────────────── */
    COUNTRY = upcase(strip(country));

    /* ── Demographics collection date = ICF date ─────────────────── */
    DMDTC = strip(icfdt);

    /* ── Study day of demographics (DMDY) ───────────────────────── */
    if strip(RFSTDTC) ne '' and strip(DMDTC) ne '' then do;
      _rfst = input(strip(RFSTDTC), yymmdd10.);
      _dmdt = input(strip(DMDTC),   yymmdd10.);
      if nmiss(_rfst, _dmdt) = 0 then do;
        if _dmdt >= _rfst then DMDY = _dmdt - _rfst + 1;
        else                   DMDY = _dmdt - _rfst;
      end;
    end;

    /* ── Death fields (not applicable in this sample) ────────────── */
    DTHDTC = '';
    DTHFL  = '';

    /* ── Drop raw input variables ────────────────────────────────── */
    drop subjectid siteid arm sex race ethnic birthdt icfdt
         firstdosedt lastdosedt enrlflag complfl country
         _bdt _idt _rfst _dmdt;

    /* ── Keep only SDTM variables in correct order ───────────────── */
    keep STUDYID DOMAIN USUBJID SUBJID SITEID INVID INVNAM
         BRTHDTC AGE AGEU SEX RACE ETHNIC
         ARMCD ARM ACTARMCD ACTARM COUNTRY
         DMDTC DMDY RFICDTC RFSTDTC RFENDTC
         RFXSTDTC RFXENDTC RFPENDTC DTHDTC DTHFL;

  run;

  /* ── Sort by USUBJID (required for DM) ──────────────────────────── */
  proc sort data=&outds.;
    by USUBJID;
  run;

  /* ── Summary ─────────────────────────────────────────────────────── */
  proc sql noprint;
    select count(*) into :n_subj trimmed from &outds.;
  quit;

  %put NOTE: [derive_dm] DM domain complete — &n_subj. subjects.;

  /* ── Quick frequency check ───────────────────────────────────────── */
  title "DM Domain — Arm Distribution";
  proc freq data=&outds.;
    tables ACTARM * SEX / nocol nopercent missing;
  run;
  title;

%mend derive_dm;


/*==============================================================================
  MACRO: %validate_dm
  Basic SDTM DM validation checks — pre-Pinnacle 21.
  Flags:
    1. Missing USUBJID
    2. Duplicate USUBJID
    3. Missing RFSTDTC
    4. AGE out of range (< 0 or > 120)
    5. Invalid SEX values
    6. RFENDTC before RFSTDTC
==============================================================================*/
%macro validate_dm(ds=sdtmdata.dm);

  %put ── [validate_dm] Running DM validation checks on &ds.;

  %local issues;
  %let issues = 0;

  /* Check 1: Missing USUBJID */
  proc sql noprint;
    select count(*) into :n trimmed
    from &ds. where missing(USUBJID);
  quit;
  %if &n. > 0 %then %do;
    %put ERROR: [validate_dm] &n. records with missing USUBJID;
    %let issues = %eval(&issues. + 1);
  %end;

  /* Check 2: Duplicate USUBJID */
  proc sql noprint;
    select count(*) into :n trimmed
    from &ds. group by USUBJID having count(*) > 1;
  quit;
  %if &n. > 0 %then %do;
    %put ERROR: [validate_dm] &n. duplicate USUBJID values found;
    %let issues = %eval(&issues. + 1);
  %end;

  /* Check 3: Missing RFSTDTC */
  proc sql noprint;
    select count(*) into :n trimmed
    from &ds. where missing(RFSTDTC);
  quit;
  %if &n. > 0 %then %do;
    %put WARNING: [validate_dm] &n. records with missing RFSTDTC;
    %let issues = %eval(&issues. + 1);
  %end;

  /* Check 4: AGE out of range */
  proc sql noprint;
    select count(*) into :n trimmed
    from &ds. where AGE < 0 or AGE > 120;
  quit;
  %if &n. > 0 %then %do;
    %put ERROR: [validate_dm] &n. records with AGE out of range (0-120);
    %let issues = %eval(&issues. + 1);
  %end;

  /* Check 5: Invalid SEX values */
  proc sql noprint;
    select count(*) into :n trimmed
    from &ds. where SEX not in ('M','F','U','UNDIFFERENTIATED');
  quit;
  %if &n. > 0 %then %do;
    %put ERROR: [validate_dm] &n. records with invalid SEX value;
    %let issues = %eval(&issues. + 1);
  %end;

  /* Check 6: RFENDTC before RFSTDTC */
  proc sql noprint;
    select count(*) into :n trimmed
    from &ds.
    where input(RFENDTC, yymmdd10.) < input(RFSTDTC, yymmdd10.)
      and not missing(RFENDTC) and not missing(RFSTDTC);
  quit;
  %if &n. > 0 %then %do;
    %put ERROR: [validate_dm] &n. records where RFENDTC < RFSTDTC;
    %let issues = %eval(&issues. + 1);
  %end;

  /* Summary */
  %if &issues. = 0 %then
    %put NOTE: [validate_dm] All DM validation checks PASSED.;
  %else
    %put WARNING: [validate_dm] &issues. issue(s) found. Review before Pinnacle 21.;

%mend validate_dm;


/*==============================================================================
  EXAMPLE USAGE
  ------------------------------------------------------------------------------
  libname rawdata  '/path/to/raw';
  libname sdtmdata '/path/to/sdtm';

  %create_raw_dm();
  %derive_dm(studyid=SAMPLE001);
  %validate_dm();
==============================================================================*/
