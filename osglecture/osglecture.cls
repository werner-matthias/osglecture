\NeedsTeXFormat{LaTeX2e}[2022/06/01]
\ProvidesExplClass
  {osglecture}
  {2026/07/29}
  {0.8.0}
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

\ExplSyntaxOn

\tl_new:N \l__osglecture_doctype_tl
\tl_new:N \l__osglecture_document_profile_tl
\tl_new:N \l__osglecture_backend_tl
\tl_new:N \l__osglecture_base_class_tl
\tl_new:N \l__osglecture_language_tl
\tl_new:N \l__osglecture_base_options_tl
\tl_new:N \l__osglecture_selected_options_tl
\tl_new:N \l__osglecture_modes_option_tl
\tl_new:N \l__osglecture_setup_file_tl
\bool_new:N \l__osglecture_doctype_explicit_bool
\bool_new:N \l__osglecture_profile_explicit_bool
\bool_new:N \l__osglecture_language_explicit_bool
\bool_new:N \l__osglecture_standalone_bool

\msg_new:nnnn { osglecture } { unsupported-doctype }
  { Unsupported~document~type~'#1'. }
  { Choose~slides,~handout,~script,~or~article. }
\msg_new:nnnn { osglecture } { profile-conflict }
  { Class~profile~'#1'~conflicts~with~build~profile~'#2'. }
  { Change~the~project~configuration~and~regenerate~the~build~file. }
\msg_new:nnnn { osglecture } { metadata-required }
  { Document~profile~'#1'~requires~\token_to_str:N\DocumentMetadata. }
  { Put~\token_to_str:N\DocumentMetadata\c_left_brace_str\c_right_brace_str~
    before~\token_to_str:N\documentclass~in~the~document~source. }
\msg_new:nnnn { osglecture } { standalone-ignores-build }
  { Standalone~mode~ignores~the~job-bound~build~file~'#1'. }
  { Remove~the~standalone~class~option~to~use~the~series~configuration. }

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
  }

\ProcessKeyOptions [ osglecture ]

\file_if_exist:nT { \c_sys_jobname_str.osgbuild.tex }
  {
    \bool_if:NTF \l__osglecture_standalone_bool
      {
        \msg_warning:nnx {osglecture}{standalone-ignores-build}
          {\c_sys_jobname_str.osgbuild.tex}
      }
      { \OsgLectureLoadBuildFileForJob }
  }

\OsgLectureBuildLoadedTF
  {
    \bool_if:NF \l__osglecture_doctype_explicit_bool
      {
        \tl_set:Ne \l__osglecture_doctype_tl
          { \OsgLectureBuildValue{doctype} }
      }
    \bool_if:NF \l__osglecture_language_explicit_bool
      {
        \tl_set:Ne \l__osglecture_language_tl
          { \OsgLectureBuildValue{language} }
      }
    \tl_set:Ne \l_tmpa_tl { \OsgLectureBuildValue{document-profile} }
    \bool_if:NTF \l__osglecture_profile_explicit_bool
      {
        \str_if_eq:VVF \l__osglecture_document_profile_tl \l_tmpa_tl
          {
            \msg_fatal:nnxx {osglecture}{profile-conflict}
              {\l__osglecture_document_profile_tl}{\l_tmpa_tl}
          }
      }
      { \tl_set_eq:NN \l__osglecture_document_profile_tl \l_tmpa_tl }
  }
  { }

\tl_if_empty:NT \l__osglecture_doctype_tl
  { \tl_set:Nn \l__osglecture_doctype_tl {slides} }
\str_case:VnF \l__osglecture_doctype_tl
  { {slides}{} {handout}{} {script}{} {article}{} }
  {
    \msg_fatal:nnV {osglecture}{unsupported-doctype}
      \l__osglecture_doctype_tl
  }
\tl_if_empty:NT \l__osglecture_document_profile_tl
  {
    \str_case:Vn \l__osglecture_doctype_tl
      {
        {slides}  { \tl_set:Nn \l__osglecture_document_profile_tl {beamer} }
        {handout} { \tl_set:Nn \l__osglecture_document_profile_tl {beamer} }
        {script}  { \tl_set:Nn \l__osglecture_document_profile_tl {scrbook} }
        {article} { \tl_set:Nn \l__osglecture_document_profile_tl {scrbook} }
      }
  }

\osglecture_profile_select:VV
  \l__osglecture_document_profile_tl \l__osglecture_doctype_tl
\tl_set:Ne \l__osglecture_backend_tl
  {
    \osglecture_profile_value:Vn
      \l__osglecture_document_profile_tl {backend}
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
\str_if_eq:VnT \l_tmpa_tl {required}
  {
    \cs_if_exist:NTF \IfDocumentMetadataTF
      {
        \IfDocumentMetadataTF { }
          {
            \msg_fatal:nnV {osglecture}{metadata-required}
              \l__osglecture_document_profile_tl
          }
      }
      {
        \msg_fatal:nnV {osglecture}{metadata-required}
          \l__osglecture_document_profile_tl
      }
  }
\tl_set:Ne \l__osglecture_selected_options_tl
  {
    \osglecture_profile_class_options:VV
      \l__osglecture_document_profile_tl \l__osglecture_doctype_tl
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
\exp_args:NV \LoadClass \l__osglecture_base_class_tl

\tl_set:Nx \l__osglecture_modes_option_tl
  { mode=\tl_use:N \l__osglecture_doctype_tl }
\exp_args:NV \PassOptionsToPackage
  \l__osglecture_modes_option_tl {osglecture-modes}
\RequirePackage{osglecture-modes}
\exp_args:NV \SetLectureModes \l__osglecture_doctype_tl
\str_if_eq:VnT \l__osglecture_backend_tl {beamer}
  { \AddLectureModes{beamer} }
\FinalizeLectureModes

\tl_set:Ne \l__osglecture_setup_file_tl
  {
    \osglecture_profile_value:Vn
      \l__osglecture_document_profile_tl {setup-file}
  }
\tl_if_empty:NF \l__osglecture_setup_file_tl
  { \exp_args:NV \file_input:n \l__osglecture_setup_file_tl }

\NewExpandableDocumentCommand \OsgLectureDocumentType { }
  { \tl_use:N \l__osglecture_doctype_tl }
\NewExpandableDocumentCommand \OsgLectureDocumentProfile { }
  { \tl_use:N \l__osglecture_document_profile_tl }
\NewExpandableDocumentCommand \OsgLectureBackend { }
  { \tl_use:N \l__osglecture_backend_tl }
\NewExpandableDocumentCommand \OsgLectureLanguage { }
  { \tl_use:N \l__osglecture_language_tl }
\NewDocumentCommand \OsgLectureStandaloneTF { m m }
  {
    \bool_if:NTF \l__osglecture_standalone_bool
      {#1}
      { \OsgLectureBuildLoadedTF {#2} {#1} }
  }

\ExplSyntaxOff
