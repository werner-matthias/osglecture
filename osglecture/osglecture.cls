\NeedsTeXFormat{LaTeX2e}[2022/06/01]
\ProvidesExplClass
  {osglecture}
  {2026/07/29}
  {0.7.0}
  {Profile-driven lecture documents}

% The unpublished historical implementation remains available explicitly.
% Keeping the dispatch before the new option parser lets the legacy code retain
% its complete option surface without teaching the new core those options.
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

\ExplSyntaxOn

\tl_new:N \l__osglecture_doctype_tl
\tl_new:N \l__osglecture_backend_tl
\tl_new:N \l__osglecture_language_tl
\tl_new:N \l__osglecture_base_options_tl
\tl_new:N \l__osglecture_modes_option_tl
\bool_new:N \l__osglecture_doctype_explicit_bool
\bool_new:N \l__osglecture_backend_explicit_bool
\bool_new:N \l__osglecture_language_explicit_bool

\msg_new:nnnn { osglecture } { unsupported-doctype }
  { Unsupported~document~type~'#1'. }
  { Choose~slides,~handout,~script,~or~article. }
\msg_new:nnnn { osglecture } { unsupported-backend }
  { Backend~'#1'~does~not~support~document~type~'#2'. }
  { Use~beamer~or~ltx-talk~for~presentation~documents;~
    script~documents~currently~use~scrbook. }

\keys_define:nn { osglecture }
  {
    osgbeamer .code:n = { },
    doctype .code:n =
      {
        \tl_set:Nn \l__osglecture_doctype_tl {#1}
        \bool_set_true:N \l__osglecture_doctype_explicit_bool
      },
    backend .code:n =
      {
        \tl_set:Nn \l__osglecture_backend_tl {#1}
        \bool_set_true:N \l__osglecture_backend_explicit_bool
      },
    lang .code:n =
      {
        \tl_set:Nn \l__osglecture_language_tl {#1}
        \bool_set_true:N \l__osglecture_language_explicit_bool
      },
    class-options .tl_set:N = \l__osglecture_base_options_tl,
  }

\file_if_exist:nT { \c_sys_jobname_str.osgbuild.tex }
  { \OsgLectureLoadBuildFileForJob }

\ProcessKeyOptions [ osglecture ]

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
    \bool_if:NF \l__osglecture_backend_explicit_bool
      {
        \tl_set:Ne \l__osglecture_backend_tl
          { \OsgLectureBuildValue{presentation-backend} }
      }
  }
  { }

\tl_if_empty:NT \l__osglecture_doctype_tl
  { \tl_set:Nn \l__osglecture_doctype_tl {slides} }

\str_case:VnF \l__osglecture_doctype_tl
  {
    {slides}
      {
        \tl_if_empty:NT \l__osglecture_backend_tl
          { \tl_set:Nn \l__osglecture_backend_tl {beamer} }
      }
    {handout}
      {
        \tl_if_empty:NT \l__osglecture_backend_tl
          { \tl_set:Nn \l__osglecture_backend_tl {beamer} }
      }
    {script}
      {
        \tl_if_empty:NT \l__osglecture_backend_tl
          { \tl_set:Nn \l__osglecture_backend_tl {scrbook} }
      }
    {article}
      {
        \tl_if_empty:NT \l__osglecture_backend_tl
          { \tl_set:Nn \l__osglecture_backend_tl {scrbook} }
      }
  }
  {
    \msg_fatal:nnV { osglecture } { unsupported-doctype }
      \l__osglecture_doctype_tl
  }

\str_case:VnF \l__osglecture_backend_tl
  {
    {beamer}
      {
        \str_case:VnF \l__osglecture_doctype_tl
          { {slides} { } {handout} { } }
          {
            \msg_fatal:nnxx { osglecture } { unsupported-backend }
              { \l__osglecture_backend_tl }
              { \l__osglecture_doctype_tl }
          }
        \tl_if_empty:NF \l__osglecture_base_options_tl
          {
            \exp_args:NV \PassOptionsToClass
              \l__osglecture_base_options_tl {beamer}
          }
        \str_if_eq:VnT \l__osglecture_doctype_tl {handout}
          { \PassOptionsToClass{handout}{beamer} }
        \LoadClass{beamer}
      }
    {ltx-talk}
      {
        \str_case:VnF \l__osglecture_doctype_tl
          { {slides} { } {handout} { } }
          {
            \msg_fatal:nnxx { osglecture } { unsupported-backend }
              { \l__osglecture_backend_tl }
              { \l__osglecture_doctype_tl }
          }
        \tl_if_empty:NF \l__osglecture_base_options_tl
          {
            \exp_args:NV \PassOptionsToClass
              \l__osglecture_base_options_tl {ltx-talk}
          }
        \str_if_eq:VnT \l__osglecture_doctype_tl {handout}
          { \PassOptionsToClass{mode=handout}{ltx-talk} }
        \LoadClass{ltx-talk}
      }
    {scrbook}
      {
        \str_case:VnF \l__osglecture_doctype_tl
          { {script} { } {article} { } }
          {
            \msg_fatal:nnxx { osglecture } { unsupported-backend }
              { \l__osglecture_backend_tl }
              { \l__osglecture_doctype_tl }
          }
        \tl_if_empty:NF \l__osglecture_base_options_tl
          {
            \exp_args:NV \PassOptionsToClass
              \l__osglecture_base_options_tl {scrbook}
          }
        \LoadClass{scrbook}
      }
  }
  {
    \msg_fatal:nnxx { osglecture } { unsupported-backend }
      { \l__osglecture_backend_tl }
      { \l__osglecture_doctype_tl }
  }

\tl_set:Nx \l__osglecture_modes_option_tl
  { mode=\tl_use:N \l__osglecture_doctype_tl }
\exp_args:NV \PassOptionsToPackage
  \l__osglecture_modes_option_tl {osglecture-modes}
\RequirePackage{osglecture-modes}
\exp_args:NV \SetLectureModes \l__osglecture_doctype_tl
\str_if_eq:VnT \l__osglecture_backend_tl {beamer}
  { \AddLectureModes{beamer} }
\FinalizeLectureModes

\NewExpandableDocumentCommand \OsgLectureDocumentType { }
  { \tl_use:N \l__osglecture_doctype_tl }
\NewExpandableDocumentCommand \OsgLectureBackend { }
  { \tl_use:N \l__osglecture_backend_tl }
\NewExpandableDocumentCommand \OsgLectureLanguage { }
  { \tl_use:N \l__osglecture_language_tl }

\ExplSyntaxOff
