/*==============================================================================
  DEFINE.XML v2.0 GENERATOR — SAS MACRO LIBRARY
  ------------------------------------------------------------------------------
  Purpose : Generate a CDISC-compliant define.xml v2.0 document from metadata
            specification Excel files (standard pharma specs format).
  Standards: CDISC Define-XML v2.0, SDTM IG 3.3, CDISC CT
  Validated: Designed for Pinnacle 21 Enterprise validation
  Author  : Adapted for BioMarin SDTM submission automation
  Usage   : %generate_define(
                study_id    = STUDY001,
                sdtm_path   = /submissions/study001/sdtm,
                specs_path  = /specs/study001_sdtm_specs.xlsx,
                output_path = /submissions/study001/define.xml,
                acrf_file   = acrf.pdf
            );
==============================================================================*/


/*==============================================================================
  MACRO 1: %read_specs
  Read all metadata sheets from the SDTM specs Excel workbook.
  Expected sheets:
    - Datasets   : dataset-level metadata (domain, label, class, structure)
    - Variables  : variable-level metadata (name, label, type, length, origin,
                   codelist, mandatory, method)
    - Codelists  : controlled terminology (codelist OID, term, NCI code)
    - Methods    : computational method definitions for derived variables
    - Comments   : dataset/variable-level traceability comments
==============================================================================*/
%macro read_specs(specs_path=);

  /* ── Datasets sheet ───────────────────────────────────────────── */
  proc import datafile="&specs_path."
    out    = work._ds_specs
    dbms   = xlsx
    replace;
    sheet  = "Datasets";
    getnames = yes;
  run;

  /* Standardise column names */
  data work.ds_specs;
    set work._ds_specs;
    /* Trim all character vars */
    array chars _character_;
    do over chars; chars = strip(chars); end;
    /* Upper-case key fields */
    Domain    = upcase(Domain);
    Class     = upcase(Class);
    Structure = strip(Structure);
    /* Build dataset OID — e.g. IG.DM */
    ds_oid = cats("IG.", Domain);
  run;

  /* ── Variables sheet ──────────────────────────────────────────── */
  proc import datafile="&specs_path."
    out    = work._var_specs
    dbms   = xlsx
    replace;
    sheet  = "Variables";
    getnames = yes;
  run;

  data work.var_specs;
    set work._var_specs;
    array chars _character_;
    do over chars; chars = strip(chars); end;
    Domain   = upcase(Domain);
    Variable = upcase(Variable);
    DataType = lowcase(DataType);   /* define.xml uses: text, integer, float, date, datetime */
    Origin   = propcase(Origin);    /* Collected / Derived / Assigned / Protocol / eDT */
    /* Build Item OID — e.g. IT.DM.USUBJID */
    item_oid = cats("IT.", Domain, ".", Variable);
    /* Mandatory flag */
    if upcase(Core) in ("REQ" "REQUIRED") then mandatory = "Yes";
    else mandatory = "No";
  run;

  /* ── Codelists sheet ──────────────────────────────────────────── */
  proc import datafile="&specs_path."
    out    = work._cl_specs
    dbms   = xlsx
    replace;
    sheet  = "Codelists";
    getnames = yes;
  run;

  data work.cl_specs;
    set work._cl_specs;
    array chars _character_;
    do over chars; chars = strip(chars); end;
    CodelistOID  = strip(CodelistOID);
    CodelistName = strip(CodelistName);
    Term         = strip(Term);
    DecodedValue = strip(DecodedValue);
    NCICode      = strip(NCICode);
  run;

  /* ── Methods sheet ────────────────────────────────────────────── */
  proc import datafile="&specs_path."
    out    = work._mth_specs
    dbms   = xlsx
    replace;
    sheet  = "Methods";
    getnames = yes;
  run;

  data work.mth_specs;
    set work._mth_specs;
    array chars _character_;
    do over chars; chars = strip(chars); end;
    method_oid = cats("MT.", upcase(Domain), ".", upcase(Variable));
  run;

  /* ── Comments sheet ───────────────────────────────────────────── */
  proc import datafile="&specs_path."
    out    = work._cmt_specs
    dbms   = xlsx
    replace;
    sheet  = "Comments";
    getnames = yes;
  run;

  data work.cmt_specs;
    set work._cmt_specs;
    array chars _character_;
    do over chars; chars = strip(chars); end;
    comment_oid = cats("COM.", upcase(Domain),
                       ifc(strip(Variable) ne "", cats(".", upcase(Variable)), ""));
  run;

  %put NOTE: [read_specs] Specs loaded successfully.;
%mend read_specs;


/*==============================================================================
  MACRO 2: %xml_encode
  Encode special XML characters in a string value.
  Replaces & < > " ' with their XML entity equivalents.
==============================================================================*/
%macro xml_encode(val);
  %local result;
  %let result = %sysfunc(tranwrd(&val., %str(&), %str(&amp;)));
  %let result = %sysfunc(tranwrd(&result., %str(<), %str(&lt;)));
  %let result = %sysfunc(tranwrd(&result., %str(>), %str(&gt;)));
  %let result = %sysfunc(tranwrd(&result., %str("), %str(&quot;)));
  %let result = %sysfunc(tranwrd(&result., %str('), %str(&apos;)));
  &result.
%mend xml_encode;


/*==============================================================================
  MACRO 3: %write_header
  Write the ODM root element and opening MetaDataVersion tag.
==============================================================================*/
%macro write_header(fileref=, study_id=, study_name=, protocol_name=,
                    mdv_oid=, acrf_file=);

  %local ts;
  %let ts = %sysfunc(datetime(), IS8601DT.);

  /* ODM root — required namespaces for define.xml v2.0 */
  put '<?xml version="1.0" encoding="UTF-8"?>';
  put '<ODM';
  put '  xmlns="http://www.cdisc.org/ns/odm/v1.3"';
  put '  xmlns:def="http://www.cdisc.org/ns/def/v2.0"';
  put '  xmlns:xlink="http://www.w3.org/1999/xlink"';
  put '  xmlns:xs="http://www.w3.org/2001/XMLSchema-instance"';
  put "  FileType=""Snapshot""";
  put "  FileOID=""&study_id..Define""";
  put "  CreationDateTime=""&ts.""";
  put '  ODMVersion="1.3.2"';
  put '  def:Context="Submission">';
  put '';
  put "  <Study OID=""&study_id."">";
  put "    <GlobalVariables>";
  put "      <StudyName>&study_name.</StudyName>";
  put "      <StudyDescription>&study_name.</StudyDescription>";
  put "      <ProtocolName>&protocol_name.</ProtocolName>";
  put "    </GlobalVariables>";
  put '';
  put "    <MetaDataVersion OID=""&mdv_oid.""";
  put '      Name="Study Metadata"';
  put '      def:DefineVersion="2.0.0"';
  put '      def:StandardName="SDTM-IG"';
  put '      def:StandardVersion="3.3">';
  put '';
  /* AnnotatedCRF leaf reference */
  put "      <def:AnnotatedCRF>";
  put "        <def:DocumentRef leafID=""LF.acrf""/>";
  put "      </def:AnnotatedCRF>";
  put '';

%mend write_header;


/*==============================================================================
  MACRO 4: %write_itemgroupdefs
  Write one <ItemGroupDef> per dataset/domain.
==============================================================================*/
%macro write_itemgroupdefs();

  /* How many datasets? */
  proc sql noprint;
    select count(*) into :n_ds trimmed from work.ds_specs;
  quit;

  %do i = 1 %to &n_ds.;

    /* Pull dataset-level attributes */
    data _null_;
      set work.ds_specs(firstobs=&i. obs=&i.);
      call symputx('ds_oid',       ds_oid,       'L');
      call symputx('domain',       Domain,        'L');
      call symputx('ds_label',     Label,         'L');
      call symputx('ds_class',     Class,         'L');
      call symputx('ds_struct',    Structure,     'L');
      call symputx('ds_purpose',   Purpose,       'L');
      call symputx('ds_repeating', Repeating,     'L');
      call symputx('ds_ref_data',  ReferenceData, 'L');
      call symputx('ds_comment',   CommentOID,    'L');
    run;

    /* Determine if this domain has an associated XPT file */
    %let xpt_leaf = LF.%lowcase(&domain.);

    put "      <!-- ═══ &domain. ═══ -->";
    put "      <ItemGroupDef OID=""&ds_oid.""";
    put "        Name=""&domain.""";
    put "        Repeating=""&ds_repeating.""";
    put "        IsReferenceData=""&ds_ref_data.""";
    put "        SASDatasetName=""&domain.""";
    put "        def:Label=""&ds_label.""";
    put "        def:Class=""&ds_class.""";
    put "        def:Structure=""&ds_struct.""";
    put "        def:Purpose=""&ds_purpose.""";
    put "        def:CommentOID=""COM.&domain.""";
    put "        def:ArchiveLocationID=""&xpt_leaf.""";
    put "        >";

    /* Write ItemRefs for all variables in this domain */
    proc sql noprint;
      select count(*) into :n_vars trimmed
      from work.var_specs
      where Domain = "&domain.";
    quit;

    proc sql noprint;
      create table work._domain_vars as
      select * from work.var_specs
      where Domain = "&domain."
      order by Order_Num;   /* assumes Order_Num column in specs */
    quit;

    %do j = 1 %to &n_vars.;
      data _null_;
        set work._domain_vars(firstobs=&j. obs=&j.);
        call symputx('v_oid',      item_oid,   'L');
        call symputx('v_mand',     mandatory,  'L');
        call symputx('v_order',    Order_Num,  'L');
        call symputx('v_key',      KeySeq,     'L');
        call symputx('v_method',   MethodOID,  'L');
      run;

      %if %length(%trim(&v_key.)) > 0 %then %do;
        put "        <ItemRef ItemOID=""&v_oid.""";
        put "          Mandatory=""&v_mand.""";
        put "          OrderNumber=""&v_order.""";
        put "          KeySequence=""&v_key.""";
        %if %length(%trim(&v_method.)) > 0 %then %do;
          put "          MethodOID=""&v_method.""";
        %end;
        put "          />";
      %end;
      %else %do;
        put "        <ItemRef ItemOID=""&v_oid.""";
        put "          Mandatory=""&v_mand.""";
        put "          OrderNumber=""&v_order.""";
        %if %length(%trim(&v_method.)) > 0 %then %do;
          put "          MethodOID=""&v_method.""";
        %end;
        put "          />";
      %end;

    %end; /* j — variables */

    put "      </ItemGroupDef>";
    put '';

  %end; /* i — datasets */

%mend write_itemgroupdefs;


/*==============================================================================
  MACRO 5: %write_itemdefs
  Write one <ItemDef> per variable across all domains.
==============================================================================*/
%macro write_itemdefs();

  proc sql noprint;
    select count(*) into :n_items trimmed from work.var_specs;
  quit;

  %do i = 1 %to &n_items.;

    data _null_;
      set work.var_specs(firstobs=&i. obs=&i.);
      call symputx('v_oid',      item_oid,    'L');
      call symputx('v_name',     Variable,    'L');
      call symputx('v_dtype',    DataType,    'L');
      call symputx('v_length',   Length,      'L');
      call symputx('v_label',    Label,       'L');
      call symputx('v_origin',   Origin,      'L');
      call symputx('v_sasname',  Variable,    'L');
      call symputx('v_sasfmt',   SASFormat,   'L');
      call symputx('v_codelist', CodelistOID, 'L');
      call symputx('v_comment',  CommentOID,  'L');
      call symputx('v_domain',   Domain,      'L');
      call symputx('v_sig_dig',  SignDigits,  'L');
    run;

    put "      <ItemDef OID=""&v_oid.""";
    put "        Name=""&v_name.""";
    put "        DataType=""&v_dtype.""";
    %if %length(%trim(&v_length.)) > 0 %then %do;
      put "        Length=""&v_length.""";
    %end;
    %if %length(%trim(&v_sig_dig.)) > 0 %then %do;
      put "        SignificantDigits=""&v_sig_dig.""";
    %end;
    put "        SASFieldName=""&v_sasname.""";
    %if %length(%trim(&v_sasfmt.)) > 0 %then %do;
      put "        SASFormat=""&v_sasfmt.""";
    %end;
    put "        def:Label=""&v_label.""";
    %if %length(%trim(&v_comment.)) > 0 %then %do;
      put "        def:CommentOID=""&v_comment.""";
    %end;
    put "        >";

    /* Origin */
    put "        <def:Origin Type=""&v_origin.""/>";

    /* Codelist reference if applicable */
    %if %length(%trim(&v_codelist.)) > 0 %then %do;
      put "        <CodeListRef CodeListOID=""&v_codelist.""/>";
    %end;

    put "      </ItemDef>";
    put '';

  %end;

%mend write_itemdefs;


/*==============================================================================
  MACRO 6: %write_codelists
  Write <CodeList> elements from the Codelists metadata sheet.
  Groups terms by CodelistOID, writes EnumeratedItem for each term.
==============================================================================*/
%macro write_codelists();

  /* Get distinct codelists */
  proc sql noprint;
    select distinct CodelistOID into :cl_list separated by '|'
    from work.cl_specs
    order by CodelistOID;
    select count(distinct CodelistOID) into :n_cls trimmed
    from work.cl_specs;
  quit;

  %do i = 1 %to &n_cls.;

    %let cl_oid = %scan(&cl_list., &i., |);

    /* Get codelist name and data type */
    data _null_;
      set work.cl_specs;
      where CodelistOID = "&cl_oid.";
      if _n_ = 1 then do;
        call symputx('cl_name',  CodelistName, 'L');
        call symputx('cl_dtype', DataType,     'L');
        call symputx('cl_nci',   NCISub,       'L');
      end;
    run;

    put "      <CodeList OID=""&cl_oid.""";
    put "        Name=""&cl_name.""";
    put "        DataType=""&cl_dtype.""";
    %if %length(%trim(&cl_nci.)) > 0 %then %do;
      put "        def:ExtendedValue=""No""";
      put "        def:NciThesaurus=""Yes""";
    %end;
    put "        >";

    /* Enumerate terms within this codelist */
    data work._cl_terms;
      set work.cl_specs;
      where CodelistOID = "&cl_oid.";
    run;

    proc sql noprint;
      select count(*) into :n_terms trimmed from work._cl_terms;
    quit;

    %do j = 1 %to &n_terms.;
      data _null_;
        set work._cl_terms(firstobs=&j. obs=&j.);
        call symputx('t_term',   Term,        'L');
        call symputx('t_decode', DecodedValue,'L');
        call symputx('t_nci',    NCICode,     'L');
      run;

      put "        <EnumeratedItem CodedValue=""&t_term.""";
      %if %length(%trim(&t_nci.)) > 0 %then %do;
        put "          def:ExtendedValue=""No""";
        put "          def:NciThesaurus=""&t_nci.""";
      %end;
      put "          >";
      %if %length(%trim(&t_decode.)) > 0 %then %do;
        put "          <Decode>";
        put "            <TranslatedText xml:lang=""en"">&t_decode.</TranslatedText>";
        put "          </Decode>";
      %end;
      put "        </EnumeratedItem>";

    %end; /* j — terms */

    put "      </CodeList>";
    put '';

  %end; /* i — codelists */

%mend write_codelists;


/*==============================================================================
  MACRO 7: %write_methoddefs
  Write <MethodDef> elements for all derived variables.
==============================================================================*/
%macro write_methoddefs();

  proc sql noprint;
    select count(*) into :n_mths trimmed from work.mth_specs;
  quit;

  %do i = 1 %to &n_mths.;

    data _null_;
      set work.mth_specs(firstobs=&i. obs=&i.);
      call symputx('m_oid',  method_oid,  'L');
      call symputx('m_name', MethodName,  'L');
      call symputx('m_type', MethodType,  'L');  /* Computation / Imputation / Transpose */
      call symputx('m_desc', Description, 'L');
    run;

    put "      <MethodDef OID=""&m_oid.""";
    put "        Name=""&m_name.""";
    put "        Type=""&m_type.""";
    put "        >";
    put "        <Description>";
    put "          <TranslatedText xml:lang=""en"">&m_desc.</TranslatedText>";
    put "        </Description>";
    put "      </MethodDef>";
    put '';

  %end;

%mend write_methoddefs;


/*==============================================================================
  MACRO 8: %write_commentdefs
  Write <def:CommentDef> elements for dataset and variable-level comments.
==============================================================================*/
%macro write_commentdefs();

  proc sql noprint;
    select count(*) into :n_cmts trimmed from work.cmt_specs;
  quit;

  %do i = 1 %to &n_cmts.;

    data _null_;
      set work.cmt_specs(firstobs=&i. obs=&i.);
      call symputx('c_oid',  comment_oid, 'L');
      call symputx('c_text', Comment,     'L');
    run;

    put "      <def:CommentDef OID=""&c_oid.""";
    put "        >";
    put "        <Description>";
    put "          <TranslatedText xml:lang=""en"">&c_text.</TranslatedText>";
    put "        </Description>";
    put "      </def:CommentDef>";
    put '';

  %end;

%mend write_commentdefs;


/*==============================================================================
  MACRO 9: %write_leafdefs
  Write <def:leaf> elements — one per XPT dataset file + one for aCRF.
==============================================================================*/
%macro write_leafdefs(sdtm_path=, acrf_file=);

  proc sql noprint;
    select count(*) into :n_ds trimmed from work.ds_specs;
  quit;

  %do i = 1 %to &n_ds.;

    data _null_;
      set work.ds_specs(firstobs=&i. obs=&i.);
      call symputx('domain',   Domain, 'L');
      call symputx('ds_label', Label,  'L');
    run;

    %let leaf_id  = LF.%lowcase(&domain.);
    %let xpt_file = %lowcase(&domain.).xpt;

    put "      <def:leaf ID=""&leaf_id.""";
    put "        xlink:href=""&xpt_file.""";
    put "        >";
    put "        <def:title>&ds_label. [&domain.]</def:title>";
    put "      </def:leaf>";

  %end;

  /* aCRF leaf */
  put "      <def:leaf ID=""LF.acrf""";
  put "        xlink:href=""&acrf_file.""";
  put "        >";
  put "        <def:title>Annotated Case Report Form</def:title>";
  put "      </def:leaf>";
  put '';

%mend write_leafdefs;


/*==============================================================================
  MACRO 10: %write_footer
  Close all open XML tags.
==============================================================================*/
%macro write_footer();
  put "    </MetaDataVersion>";
  put "  </Study>";
  put "</ODM>";
%mend write_footer;


/*==============================================================================
  MASTER MACRO: %generate_define
  Orchestrates the full define.xml generation pipeline.

  Parameters:
    study_id      - Study identifier (e.g. BMRN111)
    study_name    - Full study name
    protocol_name - Protocol number
    sdtm_path     - Path where XPT files are stored (for leaf hrefs)
    specs_path    - Full path to the SDTM specs Excel workbook
    output_path   - Full path for the output define.xml file
    acrf_file     - Filename of the annotated CRF PDF (e.g. acrf.pdf)
==============================================================================*/
%macro generate_define(
  study_id      = ,
  study_name    = ,
  protocol_name = ,
  sdtm_path     = ,
  specs_path    = ,
  output_path   = /submissions/define.xml,
  acrf_file     = acrf.pdf
);

  %put ====================================================================;
  %put [generate_define] Starting define.xml generation;
  %put   Study ID    : &study_id.;
  %put   Specs       : &specs_path.;
  %put   Output      : &output_path.;
  %put ====================================================================;

  /* Step 1 — Load all specs from Excel */
  %read_specs(specs_path=&specs_path.);

  /* Step 2 — Validate required specs are non-empty */
  %local ds_cnt var_cnt;
  proc sql noprint;
    select count(*) into :ds_cnt  trimmed from work.ds_specs;
    select count(*) into :var_cnt trimmed from work.var_specs;
  quit;

  %if &ds_cnt. = 0 %then %do;
    %put ERROR: [generate_define] No datasets found in specs. Check Datasets sheet.;
    %return;
  %end;
  %if &var_cnt. = 0 %then %do;
    %put ERROR: [generate_define] No variables found in specs. Check Variables sheet.;
    %return;
  %end;

  %put NOTE: [generate_define] Loaded &ds_cnt. datasets and &var_cnt. variables.;

  /* Step 3 — Open output file and write define.xml */
  %let mdv_oid = MDV.&study_id.;

  filename _define "&output_path." encoding="UTF-8";

  data _null_;
    file _define lrecl=32767;

    /* ── Header / ODM root ─────────────────────────────────── */
    %write_header(
      study_id      = &study_id.,
      study_name    = &study_name.,
      protocol_name = &protocol_name.,
      mdv_oid       = &mdv_oid.,
      acrf_file     = &acrf_file.
    );

    /* ── ItemGroupDefs (datasets) ──────────────────────────── */
    put "      <!-- ══════════════════════════════════════════ -->";
    put "      <!-- ITEM GROUP DEFINITIONS (Datasets)          -->";
    put "      <!-- ══════════════════════════════════════════ -->";
    put '';
    %write_itemgroupdefs();

    /* ── ItemDefs (variables) ──────────────────────────────── */
    put "      <!-- ══════════════════════════════════════════ -->";
    put "      <!-- ITEM DEFINITIONS (Variables)               -->";
    put "      <!-- ══════════════════════════════════════════ -->";
    put '';
    %write_itemdefs();

    /* ── CodeLists ─────────────────────────────────────────── */
    put "      <!-- ══════════════════════════════════════════ -->";
    put "      <!-- CODE LISTS (Controlled Terminology)        -->";
    put "      <!-- ══════════════════════════════════════════ -->";
    put '';
    %write_codelists();

    /* ── MethodDefs (derivation algorithms) ────────────────── */
    put "      <!-- ══════════════════════════════════════════ -->";
    put "      <!-- METHOD DEFINITIONS (Derivations)           -->";
    put "      <!-- ══════════════════════════════════════════ -->";
    put '';
    %write_methoddefs();

    /* ── CommentDefs ───────────────────────────────────────── */
    put "      <!-- ══════════════════════════════════════════ -->";
    put "      <!-- COMMENT DEFINITIONS                        -->";
    put "      <!-- ══════════════════════════════════════════ -->";
    put '';
    %write_commentdefs();

    /* ── Leaf references (XPT files + aCRF) ────────────────── */
    put "      <!-- ══════════════════════════════════════════ -->";
    put "      <!-- LEAF DEFINITIONS (Dataset Files + aCRF)    -->";
    put "      <!-- ══════════════════════════════════════════ -->";
    put '';
    %write_leafdefs(sdtm_path=&sdtm_path., acrf_file=&acrf_file.);

    /* ── Close tags ─────────────────────────────────────────── */
    %write_footer();

  run;

  filename _define clear;

  %put ====================================================================;
  %put [generate_define] define.xml written to: &output_path.;
  %put [generate_define] NEXT: Run Pinnacle 21 validation on the output.;
  %put ====================================================================;

%mend generate_define;


/*==============================================================================
  UTILITY MACRO: %validate_define
  Post-generation checks — counts elements, flags obvious issues.
  Run after %generate_define to catch problems before Pinnacle 21.
==============================================================================*/
%macro validate_define(output_path=);

  %put NOTE: [validate_define] Running pre-Pinnacle checks on &output_path.;

  /* Count key XML elements in the generated file */
  data _null_;
    infile "&output_path." truncover lrecl=32767;
    input line $32767.;
    retain ig_count it_count cl_count mt_count 0;
    if index(line, '<ItemGroupDef') > 0 then ig_count + 1;
    if index(line, '<ItemDef')      > 0 then it_count + 1;
    if index(line, '<CodeList')     > 0 then cl_count + 1;
    if index(line, '<MethodDef')    > 0 then mt_count + 1;
    if eof then do;
      put "NOTE: ── define.xml element counts ──────────────────";
      put "NOTE:  ItemGroupDef (datasets) : " ig_count;
      put "NOTE:  ItemDef      (variables): " it_count;
      put "NOTE:  CodeList                : " cl_count;
      put "NOTE:  MethodDef   (derivations): " mt_count;
      put "NOTE: ─────────────────────────────────────────────";
    end;
  run;

  /* Cross-check: every variable with a CodelistOID should have
     a matching CodeList OID in the output */
  proc sql noprint;
    create table work._missing_cls as
    select distinct v.CodelistOID
    from work.var_specs v
    where strip(v.CodelistOID) ne ""
      and v.CodelistOID not in (
        select distinct CodelistOID from work.cl_specs
      );
  quit;

  data _null_;
    if 0 then set work._missing_cls nobs=n;
    if n > 0 then
      put "WARNING: [validate_define] " n " CodelistOIDs referenced in Variables "
          "but not found in Codelists sheet. Run Pinnacle 21 to identify.";
    else
      put "NOTE: [validate_define] All CodelistOID references resolved OK.";
    stop;
    set work._missing_cls nobs=n;
  run;

  /* Cross-check: every MethodOID referenced should exist in Methods */
  proc sql noprint;
    create table work._missing_mths as
    select distinct v.MethodOID
    from work.var_specs v
    where strip(v.MethodOID) ne ""
      and v.MethodOID not in (
        select distinct method_oid from work.mth_specs
      );
  quit;

  data _null_;
    if 0 then set work._missing_mths nobs=n;
    if n > 0 then
      put "WARNING: [validate_define] " n " MethodOIDs referenced in Variables "
          "but not found in Methods sheet.";
    else
      put "NOTE: [validate_define] All MethodOID references resolved OK.";
    stop;
    set work._missing_mths nobs=n;
  run;

  %put NOTE: [validate_define] Pre-Pinnacle checks complete.;

%mend validate_define;


/*==============================================================================
  EXAMPLE USAGE
  ------------------------------------------------------------------------------
  Uncomment and adapt the call below for your study.

  %generate_define(
    study_id      = BMRN111,
    study_name    = %str(Study 111303 — ACH Indication),
    protocol_name = BMN111-302,
    sdtm_path     = /submissions/bmrn111/sdtm/datasets,
    specs_path    = /specs/bmrn111_sdtm_specs.xlsx,
    output_path   = /submissions/bmrn111/define/define.xml,
    acrf_file     = bmrn111_acrf.pdf
  );

  %validate_define(output_path=/submissions/bmrn111/define/define.xml);

==============================================================================*/
