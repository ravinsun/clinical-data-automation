/*==============================================================================
  ADaM DATASET: ADSL — Subject-Level Analysis Dataset
  ------------------------------------------------------------------------------
  Standard : CDISC ADaM IG v1.1
  Dataset  : ADSL (one record per subject)
  Study    : SAMPLE001 (Synthetic data — no real patient information)
  Author   : Ravinder Maramamula
  Created  : 2025

  Description:
    Derives the ADSL ADaM dataset from SDTM DM and disposition domains.
    ADSL is the foundation for all other ADaM datasets — every analysis
    dataset joins back to ADSL for population flags and baseline covariates.

  Key populations derived:
    SAFFL   — Safety Population (randomised and received at least one dose)
    FASFL   — Full Analysis Set (ITT — all randomised subjects)
    PPROTFL — Per Protocol Population
    COMPLFL — Completers Population

  Inputs  : SDTMDATA.DM
  Outputs : ADAMDATA.ADSL
==============================================================================*/


/*==============================================================================
  MACRO: %derive_adsl
==============================================================================*/
%macro derive_adsl(
  dmds    = sdtmdata.dm,
  outds   = adamdata.adsl,
  studyid = SAMPLE001
);

  %put ── [derive_adsl] Deriving ADSL from &dmds.;

  data &outds.;
    set &dmds.;

    length
      STUDYID  $12
      USUBJID  $50
      SUBJID   $20
      SITEID   $10
      AGE       8
      AGEGR1   $20
      AGEGR1N   8
      AGEU     $6
      SEX      $1
      SEXN      8
      RACE     $200
      RACEN     8
      ETHNIC   $200
      ETHNICN   8
      ARMCD    $20
      ARM      $200
      ACTARMCD $20
      ACTARM   $200
      TRT01P   $200
      TRT01PN   8
      TRT01A   $200
      TRT01AN   8
      TRTSDT    8   format=yymmdd10.
      TRTEDT    8   format=yymmdd10.
      TRTDURD   8
      RANDDT    8   format=yymmdd10.
      ICFDT     8   format=yymmdd10.
      SAFFL    $1
      FASFL    $1
      PPROTFL  $1
      COMPLFL  $1
      COUNTRY  $3
      DTHFL    $1
      DTHDTC   $10
    ;

    /* ── Pass-through from DM ─────────────────────────────────────── */
    STUDYID  = strip(STUDYID);
    USUBJID  = strip(USUBJID);
    SUBJID   = strip(SUBJID);
    SITEID   = strip(SITEID);
    AGE      = AGE;
    AGEU     = strip(AGEU);
    SEX      = strip(SEX);
    RACE     = strip(RACE);
    ETHNIC   = strip(ETHNIC);
    ARMCD    = strip(ARMCD);
    ARM      = strip(ARM);
    ACTARMCD = strip(ACTARMCD);
    ACTARM   = strip(ACTARM);
    COUNTRY  = strip(COUNTRY);
    DTHFL    = strip(DTHFL);
    DTHDTC   = strip(DTHDTC);

    /* ── Age grouping ─────────────────────────────────────────────── */
    if      AGE < 18              then do; AGEGR1='<18';    AGEGR1N=1; end;
    else if 18 <= AGE <= 40       then do; AGEGR1='18-40';  AGEGR1N=2; end;
    else if 41 <= AGE <= 64       then do; AGEGR1='41-64';  AGEGR1N=3; end;
    else if AGE >= 65             then do; AGEGR1='>=65';   AGEGR1N=4; end;

    /* ── Sex numeric ──────────────────────────────────────────────── */
    select (SEX);
      when ('M') SEXN = 1;
      when ('F') SEXN = 2;
      otherwise  SEXN = .;
    end;

    /* ── Race numeric ─────────────────────────────────────────────── */
    select (RACE);
      when ('WHITE')                             RACEN = 1;
      when ('BLACK OR AFRICAN AMERICAN')         RACEN = 2;
      when ('ASIAN')                             RACEN = 3;
      when ('AMERICAN INDIAN OR ALASKA NATIVE')  RACEN = 4;
      when ('NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER') RACEN = 5;
      when ('MULTIPLE')                          RACEN = 6;
      when ('OTHER')                             RACEN = 7;
      when ('UNKNOWN')                           RACEN = 99;
      otherwise                                  RACEN = .;
    end;

    /* ── Ethnicity numeric ────────────────────────────────────────── */
    select (ETHNIC);
      when ('HISPANIC OR LATINO')     ETHNICN = 1;
      when ('NOT HISPANIC OR LATINO') ETHNICN = 2;
      when ('UNKNOWN')                ETHNICN = 99;
      otherwise                       ETHNICN = .;
    end;

    /* ── Planned treatment (TRT01P) from ARM ──────────────────────── */
    TRT01P = strip(ARM);
    select (ARMCD);
      when ('TRTА')    TRT01PN = 1;
      when ('TRTB')    TRT01PN = 2;
      when ('PBO')     TRT01PN = 3;
      otherwise        TRT01PN = .;
    end;

    /* ── Actual treatment (TRT01A) from ACTARM ────────────────────── */
    TRT01A = strip(ACTARM);
    select (ACTARMCD);
      when ('TRTА')    TRT01AN = 1;
      when ('TRTB')    TRT01AN = 2;
      when ('PBO')     TRT01AN = 3;
      otherwise        TRT01AN = .;
    end;

    /* ── Treatment start/end dates ────────────────────────────────── */
    if strip(RFSTDTC) ne '' then
      TRTSDT = input(strip(RFSTDTC), yymmdd10.);
    if strip(RFENDTC) ne '' then
      TRTEDT = input(strip(RFENDTC), yymmdd10.);

    /* ── Treatment duration (days) ────────────────────────────────── */
    if nmiss(TRTSDT, TRTEDT) = 0 then
      TRTDURD = TRTEDT - TRTSDT + 1;

    /* ── Randomisation date = first dose date ─────────────────────── */
    RANDDT = TRTSDT;

    /* ── ICF date ─────────────────────────────────────────────────── */
    if strip(RFICDTC) ne '' then
      ICFDT = input(strip(RFICDTC), yymmdd10.);

    /* ── Population flags ─────────────────────────────────────────── */
    /* FAS/ITT — all randomised subjects */
    if not missing(ARMCD) and ARMCD ne 'SCRNFAIL'
      then FASFL = 'Y';
    else FASFL = 'N';

    /* Safety — received at least one dose (RFSTDTC populated) */
    if FASFL = 'Y' and not missing(RFSTDTC)
      then SAFFL = 'Y';
    else SAFFL = 'N';

    /* Per Protocol — Safety + completed study
       (simplified — in practice driven by protocol deviations dataset) */
    if SAFFL = 'Y' and not missing(RFENDTC)
      then PPROTFL = 'Y';
    else PPROTFL = 'N';

    /* Completers — received full planned treatment duration */
    if PPROTFL = 'Y' and TRTDURD >= 180   /* 6-month study example */
      then COMPLFL = 'Y';
    else COMPLFL = 'N';

    /* ── Keep ADSL variables only ─────────────────────────────────── */
    keep STUDYID USUBJID SUBJID SITEID
         AGE AGEGR1 AGEGR1N AGEU
         SEX SEXN RACE RACEN ETHNIC ETHNICN
         ARMCD ARM ACTARMCD ACTARM
         TRT01P TRT01PN TRT01A TRT01AN
         TRTSDT TRTEDT TRTDURD RANDDT ICFDT
         SAFFL FASFL PPROTFL COMPLFL
         COUNTRY DTHFL DTHDTC;

  run;

  /* Sort by USUBJID */
  proc sort data=&outds.;
    by USUBJID;
  run;

  /* Population summary */
  proc sql noprint;
    select count(*)                    into :n_total  trimmed from &outds.;
    select count(*) where SAFFL='Y'    into :n_saf    trimmed from &outds.;
    select count(*) where FASFL='Y'    into :n_fas    trimmed from &outds.;
    select count(*) where PPROTFL='Y'  into :n_pp     trimmed from &outds.;
    select count(*) where COMPLFL='Y'  into :n_comp   trimmed from &outds.;
  quit;

  %put NOTE: [derive_adsl] ADSL complete.;
  %put NOTE:   Total subjects : &n_total.;
  %put NOTE:   Safety (SAFFL) : &n_saf.;
  %put NOTE:   FAS    (FASFL) : &n_fas.;
  %put NOTE:   PerProt        : &n_pp.;
  %put NOTE:   Completers     : &n_comp.;

  title "ADSL — Population Flags by Treatment Arm";
  proc freq data=&outds.;
    tables TRT01A * SAFFL * FASFL / nocol nopercent missing list;
  run;
  title;

%mend derive_adsl;


/*==============================================================================
  MACRO: %validate_adsl
  Pre-Pinnacle 21 ADSL validation checks.
==============================================================================*/
%macro validate_adsl(ds=adamdata.adsl);

  %put ── [validate_adsl] Running ADSL validation checks on &ds.;

  %local issues;
  %let issues = 0;

  /* Check 1: One record per USUBJID */
  proc sql noprint;
    select count(*) into :n trimmed
    from &ds. group by USUBJID having count(*) > 1;
  quit;
  %if &n. > 0 %then %do;
    %put ERROR: [validate_adsl] &n. duplicate USUBJID — ADSL must be one record per subject;
    %let issues = %eval(&issues. + 1);
  %end;

  /* Check 2: TRTSDT missing for Safety subjects */
  proc sql noprint;
    select count(*) into :n trimmed from &ds.
    where SAFFL='Y' and missing(TRTSDT);
  quit;
  %if &n. > 0 %then %do;
    %put ERROR: [validate_adsl] &n. Safety subjects with missing TRTSDT;
    %let issues = %eval(&issues. + 1);
  %end;

  /* Check 3: TRTEDT before TRTSDT */
  proc sql noprint;
    select count(*) into :n trimmed from &ds.
    where TRTEDT < TRTSDT
      and not missing(TRTSDT) and not missing(TRTEDT);
  quit;
  %if &n. > 0 %then %do;
    %put ERROR: [validate_adsl] &n. subjects where TRTEDT < TRTSDT;
    %let issues = %eval(&issues. + 1);
  %end;

  /* Check 4: TRT01PN missing for randomised subjects */
  proc sql noprint;
    select count(*) into :n trimmed from &ds.
    where FASFL='Y' and missing(TRT01PN);
  quit;
  %if &n. > 0 %then %do;
    %put WARNING: [validate_adsl] &n. randomised subjects missing TRT01PN;
    %let issues = %eval(&issues. + 1);
  %end;

  /* Check 5: AGE missing */
  proc sql noprint;
    select count(*) into :n trimmed from &ds. where missing(AGE);
  quit;
  %if &n. > 0 %then %do;
    %put WARNING: [validate_adsl] &n. subjects with missing AGE;
    %let issues = %eval(&issues. + 1);
  %end;

  %if &issues. = 0 %then
    %put NOTE: [validate_adsl] All ADSL validation checks PASSED.;
  %else
    %put WARNING: [validate_adsl] &issues. issue(s) found. Review before Pinnacle 21.;

%mend validate_adsl;


/*==============================================================================
  EXAMPLE USAGE
  ------------------------------------------------------------------------------
  libname sdtmdata '/path/to/sdtm';
  libname adamdata '/path/to/adam';

  %derive_adsl(studyid=SAMPLE001);
  %validate_adsl();
==============================================================================*/
