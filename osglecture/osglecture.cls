\NeedsTeXFormat{LaTeX2e}[2022/06/01]
\ProvidesExplClass
  {osglecture}
  {2026/08/06}
  {0.13.0}
  {Profile-driven lecture documents}

% The unpublished historical implementation remains available explicitly.
\@ifclasswith{osglecture}{osgbeamer}
  {
    \input{osglecture-osgbeamer.code.tex}
    \endinput
  }
  { }

\RequirePackage{iftex}
\ifLuaTeX\else
  \ClassError{osglecture}
    {LuaLaTeX~is~required}
    {Run~this~document~with~LuaLaTeX.}
\fi

\RequirePackage{osglecture-config}
\RequirePackage{osglecture-profiles}
\RequirePackage{osglecture-project}

\ExplSyntaxOn

\tl_new:N \l__osglecture_doctype_tl
\tl_new:N \l__osglecture_document_profile_tl
\tl_new:N \l__osglecture_target_profile_class_tl
\tl_new:N \l__osglecture_backend_tl
\tl_new:N \l__osglecture_adapter_tl
\tl_new:N \l__osglecture_base_class_tl
\tl_new:N \l__osglecture_language_tl
\tl_new:N \l__osglecture_base_options_tl
\tl_new:N \l__osglecture_selected_options_tl
\tl_new:N \l__osglecture_setup_file_tl
\tl_new:N \l__osglecture_mode_setup_file_tl
\tl_new:N \l__osglecture_additional_modes_tl
\tl_new:N \l__osglecture_project_config_tl
\bool_new:N \l__osglecture_doctype_explicit_bool
\bool_new:N \l__osglecture_profile_explicit_bool
\bool_new:N \l__osglecture_language_explicit_bool
\bool_new:N \l__osglecture_standalone_bool
\bool_new:N \l__osglecture_native_mode_compatibility_bool
\bool_set_true:N \l__osglecture_native_mode_compatibility_bool

\msg_new:nnnn { osglecture } { profile-required }
  { Document~type~'#1'~has~no~default~document~profile. }
  { Select~a~profile~which~declares~this~document~type. }
\msg_new:nnnn { osglecture } { profile-conflict }
  { Class~profile~'#1'~conflicts~with~build~profile~'#2'. }
  { Change~the~project~configuration~and~regenerate~the~build~file. }
\msg_new:nnnn { osglecture } { metadata-required }
  { Document~profile~'#1'~requires~\token_to_str:N\DocumentMetadata. }
  { Put~\token_to_str:N\DocumentMetadata\c_left_brace_str\c_right_brace_str~
    before~\token_to_str:N\documentclass~in~the~document~source. }
\msg_new:nnnn { osglecture } { metadata-forbidden }
  { Document~profile~'#1'~does~not~support~\token_to_str:N\DocumentMetadata. }
  { Disable~document~metadata~for~this~target~or~select~another~profile. }
\msg_new:nnnn { osglecture } { metadata-policy-conflict }
  { Build~metadata~policy~'#1'~conflicts~with~profile~'#2'~('#3'). }
  { Change~the~target-specific~document_metadata~policy~or~the~target~profile. }
\msg_new:nnnn { osglecture } { standalone-job-conflict }
  { Standalone~mode~cannot~be~combined~with~an~OLLM~job. }
  { Remove~the~standalone~class~option~or~build~without~OLLM. }
\msg_new:nnnn { osglecture } { build-override }
  { Explicit~class~#1~'#2'~overrides~build~value~'#3'. }
  { This~is~intended~for~debugging;~the~job-bound~BuildSpec~remains~unchanged. }

\keys_define:nn { osglecture }
  {
    osgbeamer .code:n = { },
    standalone .bool_set:N = \l__osglecture_standalone_bool,
    doctype .code:n =
      {
        \tl_set:Nn \l__osglecture_doctype_tl {#1}
        \bool_set_true:N \l__osglecture_doctype_explicit_bool
      },
    profile .code:n =
      {
        \tl_set:Nn \l__osglecture_document_profile_tl {#1}
        \bool_set_true:N \l__osglecture_profile_explicit_bool
      },
    lang .code:n =
      {
        \tl_set:Nn \l__osglecture_language_tl {#1}
        \bool_set_true:N \l__osglecture_language_explicit_bool
      },
    class-options .tl_set:N = \l__osglecture_base_options_tl,
    native-mode-compatibility .bool_set:N =
      \l__osglecture_native_mode_compatibility_bool,
  }

\ProcessKeyOptions [ osglecture ]

\bool_if:NTF \l__osglecture_standalone_bool
  {
    \bool_lazy_or:nnT
      { \cs_if_exist_p:N \OSGLectureJobFile }
      { \cs_if_exist_p:N \OSGLectureProjectManifestFile }
      { \msg_fatal:nn {osglecture}{standalone-job-conflict} }
  }
  { \OsgLectureLoadBuildFileForJob }

\OsgLectureBuildLoadedTF
  {
    \bool_if:NTF \l__osglecture_doctype_explicit_bool
      {
        \tl_set:Ne \l_tmpa_tl { \OsgLectureBuildValue{doctype} }
        \str_if_eq:VVF \l__osglecture_doctype_tl \l_tmpa_tl
          {
            \msg_warning:nnxxx {osglecture}{build-override}
              {doctype}{\l__osglecture_doctype_tl}{\l_tmpa_tl}
          }
      }
      {
        \tl_set:Ne \l__osglecture_doctype_tl
          { \OsgLectureBuildValue{doctype} }
      }
    \bool_if:NTF \l__osglecture_language_explicit_bool
      {
        \tl_set:Ne \l_tmpa_tl { \OsgLectureBuildValue{language} }
        \str_if_eq:VVF \l__osglecture_language_tl \l_tmpa_tl
          {
            \msg_warning:nnxxx {osglecture}{build-override}
              {language}{\l__osglecture_language_tl}{\l_tmpa_tl}
          }
      }
      {
        \tl_set:Ne \l__osglecture_language_tl
          { \OsgLectureBuildValue{language} }
      }
    \tl_set:Ne \l__osglecture_target_profile_class_tl
      { \OsgLectureBuildValue{profile-class} }
  }
  { }

\tl_if_empty:NT \l__osglecture_doctype_tl
  { \tl_set:Nn \l__osglecture_doctype_tl {slides} }
\tl_if_empty:NT \l__osglecture_target_profile_class_tl
  {
    \str_case:VnF \l__osglecture_doctype_tl
      {{slides}{\tl_set:Nn \l__osglecture_target_profile_class_tl {presentation}}
       {handout}{\tl_set:Nn \l__osglecture_target_profile_class_tl {presentation}}}
      {\tl_set:Nn \l__osglecture_target_profile_class_tl {longform}}
  }

% \ldeen{Ort und Name der Projektkonfiguration kommen nicht mehr aus der
% Auftragsdatei, sondern aus dem gemeinsamen Manifest-Modul (siehe
% ARCHITECTURE.md Abschnitt 12): Es liest \code{[project.tex]} direkt aus
% dem Projektmanifest, das es selbst ausgehend vom Arbeitsverzeichnis
% findet. Ein fehlgeschlagenes Laden bleibt wie zuvor still -- die Klasse
% lädt dann einfach keine Projektkonfiguration.}{Location and name of the
% project configuration no longer come from the build file, but from the
% shared manifest module (see ARCHITECTURE.md section 12): it reads
% \code{[project.tex]} directly from the project manifest, which it finds
% itself starting from the working directory. A failed load stays silent
% as before -- the class then simply loads no project configuration.}
\OsgLectureBuildLoadedTF
  {
    \directlua{ require("osglecture-manifest").load_tex() }
    \str_if_eq:eeT { \OsgLectureManifestAvailableFlag } { 1 }
      {
        \tl_set:Ne \l__osglecture_project_config_tl
          { \OsgLectureManifestProjectConfigPath }
        \file_if_exist:VTF \l__osglecture_project_config_tl
          { \exp_args:NV \file_input:n \l__osglecture_project_config_tl }
          { }
      }
  }
  { }
\osglecture_project_suspend_metadata_commands:

\str_if_eq:VnTF \l__osglecture_target_profile_class_tl {presentation}
  { \tl_set:Nn \l_tmpa_tl {presentation-profile} }
  { \tl_set:Nn \l_tmpa_tl {longform-profile} }
\exp_args:NNV \prop_get:NnN
  \g__osglecture_project_policy_prop \l_tmpa_tl \l_tmpb_tl
\bool_set_false:N \l_tmpa_bool
\exp_args:NNV \prop_get:NnNT
  \g__osglecture_project_policy_enforced_prop \l_tmpa_tl \l_tmpd_tl
  { \str_if_eq:VnT \l_tmpd_tl {true} {\bool_set_true:N \l_tmpa_bool} }
\OsgLectureBuildLoadedTF
  {
    \tl_set:Ne \l_tmpc_tl {\OsgLectureBuildValue{target}}
    \exp_args:NNV \prop_get:NnNT
      \g__osglecture_project_target_profile_prop \l_tmpc_tl \l_tmpd_tl
      {
        \bool_if:NTF \l_tmpa_bool
          { \str_if_eq:VVF \l_tmpb_tl \l_tmpd_tl
              { \msg_fatal:nnxxx {osglecture-project}{enforced-conflict}
                  {\l_tmpa_tl}{\l_tmpb_tl}{\l_tmpd_tl} } }
          { \tl_set_eq:NN \l_tmpb_tl \l_tmpd_tl }
      }
  }
  { }
\bool_if:NTF \l__osglecture_profile_explicit_bool
  {
    \exp_args:NNV \prop_get:NnNT
      \g__osglecture_project_policy_enforced_prop \l_tmpa_tl \l_tmpc_tl
      { \str_if_eq:VnT \l_tmpc_tl {true}
          { \str_if_eq:VVF \l__osglecture_document_profile_tl \l_tmpb_tl
              { \msg_fatal:nnxx {osglecture}{profile-conflict}
                  {\l__osglecture_document_profile_tl}{\l_tmpb_tl} } } }
  }
  { \tl_set_eq:NN \l__osglecture_document_profile_tl \l_tmpb_tl }
\tl_if_empty:NT \l__osglecture_document_profile_tl
  { \msg_fatal:nnV {osglecture}{profile-required}\l__osglecture_doctype_tl }

\osglecture_profile_select:VV
  \l__osglecture_document_profile_tl \l__osglecture_doctype_tl
\tl_set:Ne \l__osglecture_backend_tl
  {
    \osglecture_profile_value:Vn
      \l__osglecture_document_profile_tl {backend}
  }
\tl_set:Ne \l__osglecture_adapter_tl
  {
    \osglecture_profile_value:Vn
      \l__osglecture_document_profile_tl {adapter}
  }
\tl_set:Ne \l__osglecture_base_class_tl
  {
    \osglecture_profile_value:Vn
      \l__osglecture_document_profile_tl {class}
  }
\tl_set:Ne \l_tmpa_tl
  {
    \osglecture_profile_value:Vn
      \l__osglecture_document_profile_tl {document-metadata}
  }
\bool_set_false:N \l_tmpa_bool
\cs_if_exist:NT \IfDocumentMetadataTF
  { \IfDocumentMetadataTF {\bool_set_true:N \l_tmpa_bool} { } }
\str_if_eq:VnT \l_tmpa_tl {required}
  {
    \bool_if:NF \l_tmpa_bool
      { \msg_fatal:nnV {osglecture}{metadata-required}
          \l__osglecture_document_profile_tl }
  }
\str_if_eq:VnT \l_tmpa_tl {forbidden}
  { \bool_if:NT \l_tmpa_bool
      { \msg_fatal:nnV {osglecture}{metadata-forbidden}
          \l__osglecture_document_profile_tl } }
\OsgLectureBuildLoadedTF
  {
    \tl_set:Ne \l_tmpb_tl
      {\OsgLectureBuildValue{document-metadata-policy}}
    \bool_lazy_or:nnT
      { \bool_lazy_and_p:nn
          {\str_if_eq_p:Vn \l_tmpa_tl {required}}
          {\str_if_eq_p:Vn \l_tmpb_tl {disabled}} }
      { \bool_lazy_and_p:nn
          {\str_if_eq_p:Vn \l_tmpa_tl {forbidden}}
          {\str_if_eq_p:Vn \l_tmpb_tl {required}} }
      { \msg_fatal:nnxxx {osglecture}{metadata-policy-conflict}
          {\l_tmpb_tl}{\l__osglecture_document_profile_tl}{\l_tmpa_tl} }
  }
  { }
\tl_set:Ne \l__osglecture_selected_options_tl
  {
    \osglecture_profile_class_options:VV
      \l__osglecture_document_profile_tl \l__osglecture_doctype_tl
  }
\tl_set:Ne \l_tmpa_tl { \OsgLectureProjectClassOptions }
\tl_if_empty:NF \l_tmpa_tl
  {
    \tl_if_empty:NF \l__osglecture_selected_options_tl
      { \tl_put_right:Nn \l__osglecture_selected_options_tl {,} }
    \tl_put_right:NV \l__osglecture_selected_options_tl \l_tmpa_tl
      }
\tl_set:Ne \l_tmpa_tl
  { \exp_args:NV \OsgLectureSetupClassOptions \l__osglecture_base_class_tl }
\tl_if_empty:NF \l_tmpa_tl
  {
    \tl_if_empty:NF \l__osglecture_selected_options_tl
      { \tl_put_right:Nn \l__osglecture_selected_options_tl {,} }
    \tl_put_right:NV \l__osglecture_selected_options_tl \l_tmpa_tl
  }
\tl_if_empty:NF \l__osglecture_base_options_tl
  {
    \tl_if_empty:NF \l__osglecture_selected_options_tl
      { \tl_put_right:Nn \l__osglecture_selected_options_tl {,} }
    \tl_put_right:NV \l__osglecture_selected_options_tl
      \l__osglecture_base_options_tl
  }
\tl_if_empty:NF \l__osglecture_selected_options_tl
  {
    \exp_args:NVV \PassOptionsToClass
      \l__osglecture_selected_options_tl \l__osglecture_base_class_tl
  }
% \ldeen*{@1 setzt Leerzeichen (Katcode~32) auf Katcode~9 (ignoriert), nicht
% Katcode~10 wie normales \LaTeX. Legacy-Basisklassen wie KOMA-Skripts @2
% verwenden intern eigene, nicht-@3-basierte Makros (etwa
% \code{\@pr@videpackage}), deren Parametermuster ein Leerzeichen als
% Trenntoken erwarten -- unter Katcode~9 verschwindet dieses Trenntoken beim
% Tokenisieren spurlos, das Muster passt nicht mehr, und die Klasse bricht
% mit einer Kaskade von Folgefehlern ab (dasselbe Symptombild wie bei einer
% früheren \code{kvoptions.sty}-Korruption in dieser Datei). Die
% Katcode-Änderung darf hier nicht in einer \TeX-Gruppe stehen: @4 verbietet
% das Laden einer Klasse innerhalb einer Gruppe explizit
% ("Loading a class or package in a group"). Die Wiederherstellung erfolgt
% deshalb durch eine zweite, ungruppierte Zuweisung direkt nach @4.}
% {@1 sets space (catcode~32) to catcode~9 (ignored), not catcode~10 as
% normal \LaTeX\ does. Legacy base classes such as KOMA-Script's @2 use
% their own, non-@3-based macros internally (e.g. \code{\@pr@videpackage}),
% whose parameter patterns expect a space as a delimiter token -- under
% catcode~9 that delimiter vanishes without a trace during tokenization,
% the pattern no longer matches, and the class aborts with a cascade of
% follow-on errors (the same symptom picture as an earlier
% \code{kvoptions.sty} corruption in this file). The catcode change must
% not be inside a \TeX\ group here: @4 explicitly forbids loading a class
% inside a group ("Loading a class or package in a group"). Restoration is
% therefore a second, ungrouped assignment right after @4.}
% {\code{\ExplSyntaxOn}}{\code{scrbook}}{expl3}{\code{\LoadClass}}
\char_set_catcode:nn {32}{10}
\exp_args:NV \LoadClass \l__osglecture_base_class_tl
\char_set_catcode:nn {32}{9}

\bool_if:NF \l__osglecture_native_mode_compatibility_bool
  { \PassOptionsToPackage{native-mode-compatibility=false}{osglecture-modes} }
\RequirePackage{osglecture-modes}
\DeclareModeBehaviorClass{presentation-dynamic}
\DeclareModeBehaviorClass{presentation-static}
\DeclareModeBehaviorClass{longform}
\AssignLectureModeBehavior{slides}{presentation-dynamic}
\AssignLectureModeBehavior{handout}{presentation-static}
\AssignLectureModeBehavior{script,article}{longform}
\tl_set:Ne \l__osglecture_mode_setup_file_tl
  {
    \osglecture_profile_value:Vn
      \l__osglecture_document_profile_tl {mode-setup-file}
  }
\tl_if_empty:NF \l__osglecture_mode_setup_file_tl
  { \exp_args:NV \file_input:n \l__osglecture_mode_setup_file_tl }
\str_case:VnF \l__osglecture_doctype_tl
  {
    {script}  { \SetLectureModes{script,article} }
    {article} { \SetLectureModes{article,script} }
  }
  { \exp_args:NV \SetLectureModes \l__osglecture_doctype_tl }
\str_if_eq:VnT \l__osglecture_backend_tl {beamer}
  { \AddLectureModes{beamer} }
\tl_set:Ne \l_tmpa_tl
  {
    \osglecture_profile_value:Vn
      \l__osglecture_document_profile_tl {modes}
  }
\tl_if_empty:NF \l_tmpa_tl { \exp_args:NV \AddLectureModes \l_tmpa_tl }
\tl_if_empty:NF \l__osglecture_additional_modes_tl
  { \exp_args:NV \AddLectureModes \l__osglecture_additional_modes_tl }
\FinalizeLectureModes

\NewExpandableDocumentCommand \OsgLectureDocumentType { }
  { \tl_use:N \l__osglecture_doctype_tl }
\NewExpandableDocumentCommand \OsgLectureDocumentProfile { }
  { \tl_use:N \l__osglecture_document_profile_tl }
\NewExpandableDocumentCommand \OsgLectureBackend { }
  { \tl_use:N \l__osglecture_backend_tl }
\NewExpandableDocumentCommand \OsgLectureAdapter { }
  { \tl_use:N \l__osglecture_adapter_tl }
\NewExpandableDocumentCommand \OsgLectureLanguage { }
  { \tl_use:N \l__osglecture_language_tl }
\NewDocumentCommand \OsgLectureStandaloneTF { m m }
  {
    \bool_if:NTF \l__osglecture_standalone_bool
      {#1}
      { \OsgLectureBuildLoadedTF {#2} {#1} }
  }

\RequirePackage{osglecture-series}
\RequirePackage{osglecture-metadata}
\ExplSyntaxOn
\exp_args:Nx \OsgLectureConfigureMetadata
  {
    course-target =
      \osglecture_profile_value:Vn
        \l__osglecture_document_profile_tl {course-target},
    event-target =
      \osglecture_profile_value:Vn
        \l__osglecture_document_profile_tl {event-target}
  }

\RequirePackage{osglecture-presitemize}
\RequirePackage{osglecture-twocolumns}
\ExplSyntaxOn
\RequirePackage{osglecture-adapters}
\exp_args:NV \OsgLectureLoadAdapter \l__osglecture_adapter_tl
\RequirePackage{osglecture-structure}
\RequirePackage{osglecture-references}
\RequirePackage{osglecture-continuation}
\ExplSyntaxOn
\OsgLectureBuildLoadedTF
  {
    \directlua{ require("osglecture-series-index").current_unit_tex() }
    \str_if_eq:eeT { \OsgLectureUnitRole } { i }
      { \RequirePackage{osglecture-integration} }
  }
  { }
\ExplSyntaxOn

\tl_set:Ne \l__osglecture_setup_file_tl
  {
    \osglecture_profile_value:Vn
      \l__osglecture_document_profile_tl {setup-file}
  }
\osglecture_configuration_priority_set:n {10}
\tl_if_empty:NF \l__osglecture_setup_file_tl
  { \exp_args:NV \file_input:n \l__osglecture_setup_file_tl }
\osglecture_configuration_priority_set:n {30}
\osglecture_project_apply_mode_setup:
\exp_args:NV \osglecture_project_include_preambles:n
  \l__osglecture_base_class_tl

\ExplSyntaxOff
