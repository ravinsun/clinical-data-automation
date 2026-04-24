/*==============================================================================
  SDTM DOMAIN: AE — Adverse Events
  ------------------------------------------------------------------------------
  Standard : CDISC SDTM IG v3.3
  Domain   : AE (Events)
  Study    : SAMPLE001 (Synthetic data — no real patient information)
  Author   : Ravinder Maramamula
  Created  : 2025

  Description:
    Derives the AE SDTM domain from raw adverse event CRF data.
    Handles serious AE flags, severity grading (CTCAE),
    relationship to study drug, action taken, and study day derivation.

  Inputs  : RAWDATA.AE_RAW   (synthetic raw AE CRF data)
            SDTMDATA.DM      (for RFSTDTC — study day anchor)
  Outputs : SDTMDATA.AE
==============================================================================*/


/*==============================================================================
  MACRO: %create_raw_ae
  Creates synthetic raw adverse event data for demonstration.
==============================================================================*/
%macro create_raw_ae();

  data rawdata.ae_raw;
    infile datalines delimiter='|' dsd truncover;
    input
      subjectid  : $20.
      aeterm     : $200.
      aestdt     : $10.
      aeendt     : $10.
      aesev      : $20.
      aeser      : $1.
      aerel      : $50.
      aeout      : $50.
      aeacn      : $100.
      aetoxgr    : $2.
      aeongo     : $1.
    ;
  datalines;
SAMPLE001-001-0001|Headache|2023-01-20|2023-01-22|MILD|N|NOT RELATED|RECOVERED/RESOLVED|NONE|1|N
SAMPLE001-001-0001|Nausea|2023-01-25|2023-02-01|MODERATE|N|POSSIBLY RELATED|RECOVERED/RESOLVED|DOSE REDUCED|2|N
SAMPLE001-001-0002|Fatigue|2023-01-22|2023-02-15|MILD|N|PROBABLY RELATED|RECOVERED/RESOLVED|NONE|1|N
SAMPLE001-001-0002|Serious Infection|2023-03-10|2023-03-20|SEVERE|Y|POSSIBLY RELATED|RECOVERED/RESOLVED|DRUG INTERRUPTED|3|N
SAMPLE001-002-0003|Dizziness|2023-01-25||MILD|N|NOT RELATED|NOT RECOVERED/NOT RESOLVED|NONE|1|Y
SAMPLE001-002-0004|Rash|2023-02-01|2023-02-10|MODERATE|N|POSSIBLY RELATED|RECOVERED/RESOLVED|NONE|2|N
SAMPLE001-003-0005|Back Pain|2023-02-05|2023-02-20|MILD|N|NOT RELATED|RECOVERED/RESOLVED|NONE|1|N
SAMPLE001-003-0005|Elevated LFTs|2023-03-15|2023-04-01|MODERATE|N|PROBABLY RELATED|RECOVERED/RESOLVED|DOSE REDUCED|2|N
SAMPLE001-003-0006|Insomnia|2023-02-02||MILD|N|POSSIBLY RELATED|NOT RECOVERED/NOT RESOLVED|NONE|1|Y
SAMPLE001-004-0007|Injection Site Reaction|2023-02-05|2023-02-07|MILD|N|RELATED|RECOVERED/RESOLVED|NONE|1|N
  ;
  run;

  %put NOTE: [create_raw_ae] Synthetic raw AE data created — &sysnobs. records.;

%mend create_raw_ae;


/*==============================================================================
  MACRO: %derive_ae
  Derives SDTM AE domain from raw adverse event CRF data.

  Key derivations:
    - AESEQ    : Sequence number within subject
    - AEDECOD  : Dictionary-derived term (MedDRA — placeholder here)
    - AEBODSYS : Body system / SOC
    - AESTDTC  : AE start date (ISO 8601)
    - AEENDTC  : AE end date (ISO 8601, blank if ongoing)
    - AESTDY   : Study day of AE start
    - AEENDY   : Study day of AE end
    - AEENRF   : End relative to reference (BEFORE/COINCIDENT/AFTER/ONGOING)
    - AESER    : Serious AE flag (Y/N)
    - AESEV    : Severity (MILD/MODERATE/SEVERE)
    - AETOXGR  : CTCAE toxicity grade
    - AEREL    : Causality / relationship to study drug
    - AEOUT    : Outcome of AE
    - AEACN    : Action taken with study treatment
    - AEONGO   : Ongoing flag
==============================================================================*/
%macro derive_ae(
  inds    = rawdata.ae_raw,
  dmds    = sdtmdata.dm,
  outds   = sdtmdata.ae,
  studyid = SAMPLE001
);

  %put ── [derive_ae] Deriving AE domain from &inds.;

  /* Merge raw AE with DM to get RFSTDTC for study day calculation */
  proc sql;
    create table work._ae_dm as
    select
      a.*,
      d.USUBJID,
      d.RFSTDTC
    from &inds. a
    left join &dmds. d
      on cats("&studyid.", '-',
              scan(strip(a.subjectid), 2, '-'), '-',
              scan(strip(a.subjectid), 3, '-'))
         = d.USUBJID;
  quit;

  /* Derive SDTM variables */
  data work._ae_derived;
    set work._ae_dm;

    length
      STUDYID  $12
      DOMAIN   $2
      USUBJID  $50
      AESEQ     8
      AETERM   $200
      AEDECOD  $200
      AEBODSYS $200
      AESTDTC  $10
      AEENDTC  $10
      AESTDY    8
      AEENDY    8
      AESEV    $20
      AESER    $1
      AEREL    $50
      AEOUT    $50
      AEACN    $100
      AETOXGR  $2
      AEONGO   $1
      AEENRF   $20
    ;

    /* ── Fixed study-level ───────────────────────────────────────── */
    STUDYID = "&studyid.";
    DOMAIN  = "AE";

    /* ── Term ────────────────────────────────────────────────────── */
    AETERM  = propcase(strip(aeterm));

    /* ── Dictionary coding (MedDRA — in production this comes from
          a coding tool like MedDRA auto-coding or manual review)    */
    AEDECOD  = AETERM;   /* placeholder — replace with coded term */
    AEBODSYS = '';        /* placeholder — replace with SOC        */

    /* ── Dates ───────────────────────────────────────────────────── */
    AESTDTC = strip(aestdt);
    if strip(aeongo) = 'Y' then AEENDTC = '';
    else AEENDTC = strip(aeendt);

    /* ── Study days ──────────────────────────────────────────────── */
    if strip(RFSTDTC) ne '' and strip(AESTDTC) ne '' then do;
      _rfst  = input(strip(RFSTDTC), yymmdd10.);
      _aestd = input(strip(AESTDTC), yymmdd10.);
      if nmiss(_rfst, _aestd) = 0 then do;
        if _aestd >= _rfst then AESTDY = _aestd - _rfst + 1;
        else                    AESTDY = _aestd - _rfst;
      end;
    end;

    if strip(RFSTDTC) ne '' and strip(AEENDTC) ne '' then do;
      _rfst  = input(strip(RFSTDTC), yymmdd10.);
      _aeend = input(strip(AEENDTC), yymmdd10.);
      if nmiss(_rfst, _aeend) = 0 then do;
        if _aeend >= _rfst then AEENDY = _aeend - _rfst + 1;
        else                    AEENDY = _aeend - _rfst;
      end;
    end;

    /* ── Severity, Seriousness, Relationship ─────────────────────── */
    AESEV   = upcase(strip(aesev));
    AESER   = upcase(strip(aeser));
    AEREL   = upcase(strip(aerel));
    AEOUT   = upcase(strip(aeout));
    AEACN   = upcase(strip(aeacn));
    AETOXGR = strip(aetoxgr);
    AEONGO  = upcase(strip(aeongo));

    /* ── End relative to reference ───────────────────────────────── */
    if AEONGO = 'Y' then AEENRF = 'ONGOING';
    else if strip(AEENDTC) ne '' and strip(RFSTDTC) ne '' then do;
      _aeend = input(strip(AEENDTC), yymmdd10.);
      _rfst  = input(strip(RFSTDTC), yymmdd10.);
      if      _aeend < _rfst  then AEENRF = 'BEFORE';
      else if _aeend = _rfst  then AEENRF = 'COINCIDENT';
      else                         AEENRF = 'AFTER';
    end;

    drop aeterm aestdt aeendt aesev aeser aerel aeout aeacn
         aetoxgr aeongo subjectid RFSTDTC
         _rfst _aestd _aeend;

    keep STUDYID DOMAIN USUBJID AESEQ AETERM AEDECOD AEBODSYS
         AESTDTC AEENDTC AESTDY AEENDY AESEV AESER AEREL
         AEOUT AEACN AETOXGR AEONGO AEENRF;

  run;

  /* Assign AESEQ within USUBJID */
  proc sort data=work._ae_derived;
    by USUBJID AESTDTC AETERM;
  run;

  data &outds.;
    set work._ae_derived;
    by USUBJID;
    if first.USUBJID then _seq = 0;
    _seq + 1;
    AESEQ = _seq;
    drop _seq;
  run;

  /* Summary */
  proc sql noprint;
    select count(*)            into :n_ae    trimmed from &outds.;
    select count(distinct USUBJID) into :n_subj trimmed from &outds.;
    select count(*)            into :n_ser   trimmed from &outds. where AESER='Y';
  quit;

  %put NOTE: [derive_ae] AE domain complete.;
  %put NOTE:   Total AEs    : &n_ae.;
  %put NOTE:   Subjects     : &n_subj.;
  %put NOTE:   Serious AEs  : &n_ser.;

  /* Frequency summary */
  title "AE Domain — Severity by Seriousness";
  proc freq data=&outds.;
    tables AESEV * AESER / nocol nopercent missing;
  run;
  title;

%mend derive_ae;


/*==============================================================================
  MACRO: %validate_ae
  Pre-Pinnacle 21 AE validation checks.
  Flags:
    1. Missing AETERM
    2. Missing AESTDTC
    3. AEENDTC before AESTDTC
    4. Ongoing AE with an end date populated
    5. Invalid AESER values
    6. Invalid AESEV values
    7. AETOXGR not in 1-5
==============================================================================*/
%macro validate_ae(ds=sdtmdata.ae);

  %put ── [validate_ae] Running AE validation checks on &ds.;

  %local issues;
  %let issues = 0;

  /* Check 1: Missing AETERM */
  proc sql noprint;
    select count(*) into :n trimmed from &ds. where missing(AETERM);
  quit;
  %if &n. > 0 %then %do;
    %put ERROR: [validate_ae] &n. records with missing AETERM;
    %let issues = %eval(&issues. + 1);
  %end;

  /* Check 2: Missing AESTDTC */
  proc sql noprint;
    select count(*) into :n trimmed from &ds. where missing(AESTDTC);
  quit;
  %if &n. > 0 %then %do;
    %put ERROR: [validate_ae] &n. records with missing AESTDTC;
    %let issues = %eval(&issues. + 1);
  %end;

  /* Check 3: AEENDTC before AESTDTC */
  proc sql noprint;
    select count(*) into :n trimmed from &ds.
    where input(AEENDTC, yymmdd10.) < input(AESTDTC, yymmdd10.)
      and not missing(AEENDTC) and not missing(AESTDTC);
  quit;
  %if &n. > 0 %then %do;
    %put ERROR: [validate_ae] &n. records where AEENDTC < AESTDTC;
    %let issues = %eval(&issues. + 1);
  %end;

  /* Check 4: Ongoing AE with end date */
  proc sql noprint;
    select count(*) into :n trimmed from &ds.
    where AEONGO = 'Y' and not missing(AEENDTC);
  quit;
  %if &n. > 0 %then %do;
    %put WARNING: [validate_ae] &n. ongoing AEs have AEENDTC populated;
    %let issues = %eval(&issues. + 1);
  %end;

  /* Check 5: Invalid AESER */
  proc sql noprint;
    select count(*) into :n trimmed from &ds.
    where AESER not in ('Y','N');
  quit;
  %if &n. > 0 %then %do;
    %put ERROR: [validate_ae] &n. records with invalid AESER (expected Y/N);
    %let issues = %eval(&issues. + 1);
  %end;

  /* Check 6: Invalid AESEV */
  proc sql noprint;
    select count(*) into :n trimmed from &ds.
    where AESEV not in ('MILD','MODERATE','SEVERE');
  quit;
  %if &n. > 0 %then %do;
    %put ERROR: [validate_ae] &n. records with invalid AESEV value;
    %let issues = %eval(&issues. + 1);
  %end;

  /* Check 7: AETOXGR out of range */
  proc sql noprint;
    select count(*) into :n trimmed from &ds.
    where not missing(AETOXGR)
      and AETOXGR not in ('1','2','3','4','5');
  quit;
  %if &n. > 0 %then %do;
    %put ERROR: [validate_ae] &n. records with AETOXGR not in 1-5;
    %let issues = %eval(&issues. + 1);
  %end;

  %if &issues. = 0 %then
    %put NOTE: [validate_ae] All AE validation checks PASSED.;
  %else
    %put WARNING: [validate_ae] &issues. issue(s) found. Review before Pinnacle 21.;

%mend validate_ae;


/*==============================================================================
  EXAMPLE USAGE
  ------------------------------------------------------------------------------
  libname rawdata  '/path/to/raw';
  libname sdtmdata '/path/to/sdtm';

  %create_raw_ae();
  %derive_ae(studyid=SAMPLE001);
  %validate_ae();
==============================================================================*/
