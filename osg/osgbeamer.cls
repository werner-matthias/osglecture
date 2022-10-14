\NeedsTeXFormat{LaTeX2e}[2022/06/01]
\def\classname{osgbeamer}
\ProvidesClass{\classname}[2022/08/17 v0.9.0d]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Beamer- und Script-Template für die Professur Betriebssysteme an
% der TU Chemnitz
%
% (c) Matthias Werner (matthias.werner@informatik.tu-chemnitz.de), 2022
%
% Dieses Material steht unter der Creative-Commons-Lizenz CC BY-SA 4.0
% (Namensnennung - Weitergabe unter gleichen Bedingungen).
% Um eine Kopie dieser Lizenz zu sehen, besuchen Sie                                        
% http://creativecommons.org/licenses/by-sa/4.0/deed.de.                      
%
% Hinweis:
% Obwohl diese Klasse eigenständig genutzt werden kann, ist sie primär
% für den Einsatz in Vorlesungsreihen im Kombination mit dem
% OSG LaTeX Lecture Maker (einem rc-Script für latexmk) gedacht.
%
\IfFormatAtLeastTF{2022/06/01}{}{
\ClassError{\classname}{\MessageBreak
************************************************\MessageBreak
* This class requires at least the TeX format \MessageBreak
* from 2022/06. \MessageBreak
************************************************
 }{Update your LaTeX.}
}
\RequirePackage{iftex}               % für Test auf Lua(La)TeX
\ifLuaTeX\else
\ClassError{\classname}{\MessageBreak
************************************************\MessageBreak
* LuaLaTeX is required to use this class. \MessageBreak
* Sorry! \MessageBreak
************************************************
 }{Use this class with LuaLaTex.}
\fi
\RequirePackage{etoolbox}
% Die nächsten beiden Zeilen dienen nur dafür, dass mein Editor die
% etoolbox-if nicht dauernd mit TeX-if verwechselt.
\let\IfBool=\ifbool 
\let\IfToggle=\iftoggle
% \if's verwechselt...

\RequirePackage{varsfromjobname}
\RequirePackage{luacode}
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% OSG LaTeX Lecture Maker
% =======================
% 
% Das OSG LaTeX lecture maker system (OLLM system) steht teilweise über den
% Klassenoptionen. Im OLLM System werden an die Klasse durch den Jobnamen und 
% durch vordefinierte Macros Informationen übergeben. Macros und Jobnamen werden
% durch das `latexmkrc` aufgearbeitet.
% Der Jobname ist wie folgt aufgebaut und wird ausgewertet, wenn das Macro
% `ollm` definiert ist.
%
% <lectureprefix>-<number>-<doctype>-<language>-<topic>
%
% * <lectureprefix>: wahlfreies Kürzel für die Vorlesungsreihe
% * <number>       : zweistellig Nummer des Kapitels
% * <doctype>      : Ausgabeformat (siehe unten)
% * <language>     : de oder en (für deutsch oder englisch)
% * <topic>        : wahlfreie Bezeichnung für das Kapitelthema
%
% Ob das OLLM System aktiv ist, wird anhand des Vorhandenseins des Macro '\ollm'
% festgestellt und im Flag 'osgllm' gespeichert. Dann wird davon ausgegangen,
% dass ein korrektes Verzeichnis-Layout existiert.
\newbool{osgllm}\boolfalse{osgllm}
\ifdef{\ollm}{
  \booltrue{osgllm}
}{
  \boolfalse{osgllm}
}
\newtoggle{osgscript}         % Wird bis zum Laden von Beamer als Unterscheidung
                              % von presentation- und article-Mode genutzt

\newbool{osgoptionstandalone} % Zeigt die Nutzung der Klasse außerhalb einer
                              % Lecture-Serie an

\newbool{osglegacy}           % Zeigt die Nutzung des "Kompatibilitätsmodus" an
\boolfalse{osglegacy}         


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Klassenoptionen
%
% Durch das neue Key-Value-interface von LaTeX ab Juni 2022 können (wie in
% pgfkeys oder Koma-Script Klassenoptionen ggf. auch noch später gesetzt
% werden (so sie nicht vor der ersten Seitenserstellung gebraucht werden).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\DeclareKeys{
  % Soll die Kompatibilität zur alten osgbeamer-Klasse erhöhen (z.Z. nicht genutzt)
  legacy.code={
    \GenericWarning{\classname}{Legacy mode activated}
    \booltrue{osglegacy}
  },
  % Optionen, die an die beamer-Klasse weitergeleitet werden.
  beamer.code = {
    \PassOptionsToClass{#1}{beamer}
  },
  % Da 'aspectratio' vermutlich häufiger als andere Optionen abweicht, erhält es
  % eine eigene Option
  aspectratio.code={
    \PassOptionsToClass{aspectratio=#1}{beamer}
  },
  % Optionen, die an die scrbook-Klasse weitergeleitet werden.
  article.code = {
    \PassOptionsToClass{#1}{scrbook}
  },
  % Optionen, die an das tucbeamer-Package weitergeleitet werden.
  tuc.code={
    \PassOptionsToPackage{#1}{beamerthemetuc2019}
    %\PassOptionsToPackage{#1}{beamerarticletuc2019}
  },
  % Optionen für Umgang mit Literaturreferenzen
  bib.code = {
    \PassOptionsToPackage{#1}{osgbeamerbib}
  },
  % Werden Seiten Kapitelübergreifend numeriert?
  continuation.code={
    \PassOptionsToClass{continuation=#1}{osgbeamerref}
  },
  % Optionen, die sinnvolle Einstellungen für die OSG zusammenfassen
  osgdefaults.code = {
    \PassOptionsToPackage{fakcolor=if,latexfonts}{beamerthemetuc2019}
    \PassOptionsToPackage{fakcolor=if,latexfonts}{beamerarticletuc2019}
    \SetLogo{OSG-Logo}
    \PassOptionsToClass{professionalfonts}{beamer}
  }
}
% Da Choice-Keys benötigt werden, die noch nicht nach LaTeX2e
% zurückportiert wurden, wird LaTeX3 benötigt. Daher wird auf die
% alternative Syntax umgestellt. Ein explizites Laden eines
% LaTeX3-Pakets ist nicht nötig, da die aktuelle LaTeX-Version auf
% LaTeX3 beruht.
\ExplSyntaxOn
\cs_generate_variant:Nn \keys_set:nn { nx } % SetKey mit Expansion der Werteargumente
\let\SetKeyEx=\keys_set:nx                  % Alias mit LaTeX2e-Syntax
\keys_define:nn {osgbeamer}{
  % Eine Standalone-Präsentation ist nicht Teil einer Serie
  standalone .choice:,
  standalone/lecture .code={
    \PassOptionsToPackage{continuation=none}{osgbeamerref}
    \booltrue{osgoptionstandalone}
  },
  standalone/nolecture .code={
    \undef{\ollm}
    \boolfalse{osgllm}
    \booltrue{osgoptionstandalone}
    \PassOptionsToPackage{standalone}{osgbeamerref}
    \ClassInfo{\classname}{OLLM disabled or not detected, deactivate OLLM features}
  },
  %standalone .default = {nolecture},
  % Doctype
  % =======
  %
  % Es können mehrere Arten von Ausgabeformaten (Doctypes) erzeugt werden:
  % * slides  => Foliensatz,
  % * handout => 4 Slides auf einem Blatt,
  % * screen  => Slides mit Kommentaren und Vorschau für die
  %              Vorführung (z.Z. nicht richtig unterstützt)
  % * script  => Kapitel eines Scripts
  %
  % In der Regel sollte diese Option unter OLLM nicht per Hand gesetzt werden.
  doctype .choice: ,
  doctype/slides .code:n={
    \gdef\osgparentclass{beamer}
    \togglefalse{osgscript}
  },
  doctype/handout .code:n={
    \PassOptionsToClass{handout}{beamer}
    \togglefalse{osgscript}
  },
  doctype/script .code:n={
    \toggletrue{osgscript}
  },
  doctype/screen .code:n={
    \PassOptionsToClass{second}{beamer}
    \togglefalse{osgscript}
  },
  % Die Sprache _kann_ explizit mit der Option lang=<lang> gesetzt werden, jedoch
  % sollte dies primär im 'standalone'-Mode genutzt werden
  % Im OLLM wird die entsprechende Sprache i.d.R. über den Jobnamen
  % gesetzt (siehe osgbeamerlanguage.sty)
  lang .choice:,
  lang/de .code:n = {
    \providecommand\selectedbeamerlanguage{de}
    \PassOptionsToPackage{de}{osgbeamerlanguage}
  },
  lang/en .code:n = {
    \providecommand\selectedbeamerlanguage{en}
    \PassOptionsToPackage{en}{osgbeamerlanguage}
  },
  
  % Mit der Option 'handout format' kann angegeben werden, wieviel Folien
  % auf einer A4 Seite dargestellt werden.
  % Es gibt die Auswahl zwischen '2 on 1', '4 on 1' und '6 on 1'
  handout~format.choice:,
  handout~format/2~on~1 .code ={
    \gdef\osg@pgfpageoptions{{2~on~1}[a4paper, border~shrink=2mm]}
  },
  handout~format/4~on~1 .code ={
    \gdef\osg@pgfpageoptions{{4~on~1}[a4paper, landscape, border~shrink=2mm]}
  },
  handout~format/6~on~1 .code ={
    \gdef\osg@pgfpageoptions{{6~on~1}[a4paper, border~shrink=2mm]}
  },
}
\ExplSyntaxOff

% In \ollm werden die Pfade zum Verzeichnis für gemeinsame Daten (für vorlesungsübergreifende
% Referenzierung), der eigene Verzeichnisname sowie die erste logische Kapitelnummer
% (i.d.R. 0 oder 1) übergeben.
\IfBool{osgllm}{
  \ClassInfo{\classname}{Acivate OLLM}  
  \ollm % Definiert \OsgShareDataPath, \OsgCurrentDir und \OsgFirstChapter
}{
  \boolfalse{osgllm}
  % Ohne OLLM ist das Dokument alleinstehend (standalone), auch
  % wenn dies nicht explizit als Option angegeben wurde.
  \SetKeys{standalone=true} 
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Default-Einstellungen:
%
% Hier werden (aus Sicht des Klassenautoren) sinnvolle
% Voreinstellungen getroffen.
%
\SetKeys{
  aspectratio=1610,
  tuc={
    fakcolor=if,
  },
  beamer={
    ignorenonframetext,
    10pt,
    unknownkeysallowed %,notheorems
  },
  article={
    chapterprefix=true,
    twoside,
    open=right,
    cleardoublepage=current,
    parskip=half,
    DIV=9,
    fontsize=10pt
  },
  handout format=4 on 1,
}
\SetKeyEx{osgbeamer}{
  bib={file = \getonefromjobname,
    off}
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Es gibt drei Möglichkeiten, wie spezifische Klassenoptionen gesetzt
% werden können:
%   1. Mit \SetGlobalClassOptions in lectdatex.tex. Die hier gesetzten
%      Optionen gelten für *alle* Kapitel.
%   2. Als 'normale' Klassenoption. Die so gesetzten Optionen gelten
%      nur in dem Kapitel und überschreiben die Optionen von 1.
%   3. Mit \EntforceGlobalClassOptions in lectdatex.tex. Die hier gesetzten
%      Optionen gelten für *alle* Kapitel und überschreiben Optionen
%      von 1. und 2.
%
% Frühe Optionen
% ==============
% 
% Um Klassen-Optionen für *alle* Kapitel/Lectures gemeinsam setzen zu können,
% soll die 'lectdate.tex' bereits jetzt eingelesen werden.
% Dort werden die Macros \SetGlobalClassOption und
% \EnforceGlobalClassOptions zur Verfügung gestellt.
\let\SetGlobalClassOptions=\SetKeys
\NewDocumentCommand{\EnforceGlobalClassOptions}{m}{
  \gappto{\osg@forceoptionhook}{\SetKeys{#1}}}

% Allerdings sind zu diesem Zeitpunkt die meisten Titelbefehle noch
% nicht bekannt oder noch nicht von Beamer umdefiniert.
% Daher werden sie hier temporär definiert und ihre eigentliche
% Ausführung auf später verschoben.
\gdef\osg@titlematterhook{}            % Hook für Titelbefehle
\gdef\osg@forceoptionhook{}            % Hook für Options

% Bereite die Befehle auf ihre spätere Ausführung vor
% 
% Anmerkung: Praktisch alle Titelmacros werden durch Beamer, Koma oder OSG-Beamer
% überschrieben. Da jedoch (vermutlich) häufig auf die Kernel-Definition zurückgegriffen
% wird, ist es sinnvoll, diese zu erhalten.
% 
% In der Stern-Variante definiert \osg@makedelayed das Ersatzmacro mit einem optionalen
% Argument, so wie es später auch durch Beamer und co. definiert wird.
% 
% Alle Titlemacros sind gewahr (wie übersetzt man 'aware'?) der Beamer-Modes, es lassen
% sich also mode-spezifische Titel (z.B. \title<article>{Foo}) spezifizieren. Dies wird
% *nicht* im Macro selbst verankert, sondern über eine \mode-Umgebung zur verzögerten
% Ausführung realisiert; entsprechend stehen die Modes außerhalb von 'lectdates.tex' nicht
% zur Verfügung (auch nicht in von 'lectdates.tex' includierten Dateien).
\NewDocumentCommand{\osg@makedelayed}{s m}{
  % Wenn das Macro schom (durch den Kernel) definiert ist, speichere es unter einem anderen
  % Namen, sonst setzte es auf \relax.
  \ifcsdef{#2}{\ExpandArgs{cc}\NewCommandCopy{original@#2}{#2}}{\cslet{original@#2}{\relax}}
  \IfBooleanTF{#1}{ % Stern => mit optionalem Argument
     \ExpandArgs{c}\DeclareDocumentCommand{#2}{d<> O{} m}{ % Definiere Ersatzmacro
      \IfNoValueTF{##1}{
        \gappto{\osg@titlematterhook}{\csuse{#2}[##2]{##3}}
      }{
        \gappto{\osg@titlematterhook}{\mode<##1>{\csuse{#2}[##2]{##3}}}
      }
    }
  }{ % kein Stern => ohne optionales Argument
    \ExpandArgs{c}\DeclareDocumentCommand{#2}{d<> m}{      
      \IfNoValueTF{##1}{
        \gappto{\osg@titlematterhook}{\csuse{#2}{##2}}
      }{
        \gappto{\osg@titlematterhook}{\mode<##1>{\csuse{#2}{##2}}}
      }
    }
  }
}
% Setze Macoro auf die alte Definition zurück oder (wenn vorher nicht definiert) lösche es.
\NewDocumentCommand{\osg@restoredelayed}{m}{
  \ifcsvoid{original@#1}{\csundef{#1}}{\ExpandArgs{cc}\DeclareCommandCopy{#1}{original@#1}}
}
% Da \logo schon anderweitig von Beamer belegt, von der Logik aber in eine Reihe
% wie \author,\date etc. passt, wird für lectdates.tex \logo auf \SetLogo umgelenkt
\NewDocumentCommand{\SetLogo}{O{#2} m}{
  \gdef\osg@logo{#2}
  \gdef\osg@tinylogo{#1}
}
\let\logo=\SetLogo

\IfBool{osgllm}{ % Zu diesem Zeitpunkt sind die Klassenoptionen noch nicht
  % ausgewertet. lectdates.tex wird also auch geladen, wenn OLLM korrekte
  % Verzeichnisstrukturen vorfindet und der Nutzer nicht 'standalone' nicht
  % als OLLM-Option übergibt, sondern nur als Klassenoption
  \expandafter\InputIfFileExists{\OsgLectConfig}{
    \osg@makedelayed*{author}
    \osg@makedelayed*{date}
    \osg@makedelayed*{course}
    \osg@makedelayed*{event}
    \osg@makedelayed*{lehrveranstaltung}
    \osg@makedelayed*{institute}
    \osg@makedelayed*{tucurl}
    \osg@makedelayed{input}
    \let\SetGlobalClassOptions=\SetKeys
  }{}
  \expandafter\IfFileExists{\OsgLectConfig}{
    \osg@restoredelayed{author}
    \osg@restoredelayed{date}
    \osg@restoredelayed{course}
    \osg@restoredelayed{event}
    \osg@restoredelayed{lehrveranstaltung}
    \osg@restoredelayed{institute}
    \osg@restoredelayed{tucurl}
    \osg@restoredelayed{input}
  }{}
}{}
\undef\logo          % \logo wird wieder freigegeben, so dass Beamer es neu
                     % definieren kann,
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Verarbeite Optionen
\ProcessKeyOptions   % Klassenoptionen können die Keys von \SetGlobalClassOptions
                     % überschreiben... 
\osg@forceoptionhook % ... die wiederum durch \EnforceGlobalClassOptions überschrieben
                     % werden können, da im Hook \osg@forceoptionhook Key-Settings
                     % gesammelt worden, und hier *nach* \Processoptions ausgeführt werden.
\IfBool{osgllm}{
  % Bei OLLM werden Sprache und Dokumentart aus dem Jobnamen geholt.
  % ACHTUNG: ggf. gesetzte Klassenoptionen für Sprache/Dokumentart werden überschrieben.
  \SetKeyEx{osgbeamer}{lang=\getfourfromjobname,doctype=\getthreefromjobname}
}{}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Basisklasse
%
% Je nach Dokumentmodus wird entweder beamer.cls oder scrbook.cls (zusammen mit
% beamerarticle.sty) geladen.
\IfToggle{osgscript}{
  % Script-Mode 
  \LoadClass[twoside]{scrbook}
  \RequirePackage{beamerarticle}
  \RequirePackage{beamerarticleosg}
  %\RequirePackage{scrhack}
}{
  \LoadClass{beamer}
  %%% Handout
  \mode<handout>{
    \RequirePackage{pgfpages}
    \expandafter\pgfpagesuselayout\osg@pgfpageoptions
  }
}
% Die Basisklasse (+ggf. beamerarticle) ist geladen.
% Ab jetzt enspricht osgscript = true dem article-Mode,
% false dem presentation-Mode.
% Im Prinzip würde jetzt in das Beamer-Theme einerseits und in
% beamerarticle.sty andererseits verzweigt werden. Jedoch sind einige
% Einstellungen in allen Modi gemeinsam, daher erfolgen 
% sie hier in der Klasse und nicht im Theme/beamerarticle

% Jetzt werden erst mal ein paar Standard-Packages geladen
\RequirePackage{fontspec}
\RequirePackage{xcolor}
\RequirePackage{luacolor}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Legacy Code
% ===========
%
% Mit der 'legacy'-Option wird die Klasse kompatibler zu den Dokumenten der
% alten OSGBeamer-Klasse gemacht, jedoch fehleranfälliger, da z.T. das erwartete
% Standardverhalten unter LaTeX ausgehebelt wird. Alte Dokumente sollten daher
% so schnell wie möglich angepasst und auf das Setzen der 'legacy'-Option
% verzichtet werden.
%
% In der alten OSGBeamer-Klasse gab es einige Macros und Konstrukte,
% die mittelfristig wegfallen sollen. Mit Hilfe der 'legacy'-Option
% werden einige davon aktiviert, um die Kompatibilität zu erhöhen.
% Beim Einsatz dieser Macros wird eine Warnung gegeben.
\IfBool{osglegacy}{
  \NewDocumentCommand{\DeprecationWarning}{m o}{%
    \IfNoValueTF{#2}{\def\@suf{}}{\def\@suf{, #2}}%
    \ClassWarning{osgbeamer}{Use of '\expandafter\@firstoftwo\string\@#1' is deprecated\@suf}%
  }
  % 
  \NewDocumentCommand\NewCSDeprecatedCommand{m m m O{}}{%
    \ExpandArgs{c}\NewDocumentCommand{#1}{#2}{#3\DeprecationWarning{#1}[#4]}
  }
  \NewDocumentCommand\RenewCSDeprecatedCommand{m m m O{}}{%
    \ExpandArgs{c}\RenewDocumentCommand{#1}{#2}{#3\DeprecationWarning{#1}[#4]}
  }
  % Mit scrlfile (aus dem KOMA-Packet) können unter LuaLaTex und OSGBeamer
  % überflüssige oder störende Pakete gezielt unterdrückt oder angepasst werden.
  \RequirePackage{scrlfile}
  \PreventPackageFromLoading*[
  \ClassWarning{\classname}{Package 'fontenc' is not needed for LuaLaTeX.\MessageBreak
   Please remove \string\usepackage[...]{fontenc}\MessageBreak}
  ]{fontenc}
  \PreventPackageFromLoading*[
  \ClassWarning{\classname}{Package 'inputenc' is not needed for LuaLaTeX.\MessageBreak
   Please remove \string\usepackage[...]{inputenc}\MessageBreak}
  ]{inputenc}
}{}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% Umgang mit Beamer-Modi
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% Hilfsbefehl \makeselectable: Redefiniert ein Macro für die
% Verwendung mit beamer-Aktionen. Optionaler Parameter gibt den
% Default-Mode (*mit* spitzen Klammern) 
% % TODO: Behandlung von optionalen Parametern
\NewDocumentCommand\makeselectable{m o}{
  \expandafter\let\csname\detokenize{#1}@osg@orig\endcsname=#1%
  \renewcommand<>{#1}{%
    \only##1{\csname\detokenize{#1}@osg@orig\endcsname}}%
  \IfNoValueTF{#2}{%
    \renewcommand<>{#1}{\only##1{\csname\detokenize{#1}@osg@orig\endcsname}}%
  }{%
    \renewcommand<>{#1}{\IfBlankTF{##1}{%
        \only#2{\csname\detokenize{#1}@osg@orig\endcsname}%
      }{%
        \only##1{\csname\detokenize{#1}@osg@orig\endcsname}%
      }%
    }%
  } %
}  

\makeselectable{\smallskip}[<presentation>]
\makeselectable{\medskip}[<presentation>]
\makeselectable{\bigskip}[<presentation>]
\makeselectable{\TINY}
\makeselectable{\Tiny}
\makeselectable{\tiny}
\makeselectable{\scriptsize}
\makeselectable{\footnotesize}
\makeselectable{\small}
\makeselectable{\normalsize}
\makeselectable{\large}
\makeselectable{\Large} 
\makeselectable{\LARGE}

% \vspace kann wegen der Stern-Variante nicht direkt selektierbar
% gemacht werden. Dafür werden die unterliegenden Macros \@vspacer und
% \@vspace gepatcht.
\let\osg@original@@vspacer=\@vspacer
\let\osg@original@@vspace=\@vspace
\renewcommand<>{\@vspacer}{\alt#1{\osg@original@@vspacer}{\@gobble}}
\renewcommand<>{\@vspace}{\alt#1{\osg@original@@vspace}{\@gobble}}

% Newline (\\) ist schon durch Beamer selectierbar gemacht. Allerdings
% definieren einige Umgebungen das Macro neu. Wenn innerhalb einer
% solchen Umgebung die Beamer-Variante gebraucht wird, kann sie mit
% \activateSelDS und \deactivateSelDS aktiviert bzw. wieder
% deaktiviert werden.
\let\beameroriginal@dsl=\\
\let\temp@dsl=\relax
\NewDocumentCommand\activateSelDS{}{
  \temp@dsl=\\%
  \let\\=\beameroriginal@dsl%
}
\NewDocumentCommand\deactivateSelDS{}{
  \let\\=\temp@dsl
}

% \osgpresart erhält zwei Argumente: das erste wird im
% presentation-Mode verwendet, das zweite im article-Mode. Das jeweils
% andere wird verschluckt.
\NewDocumentCommand\osgpresart{+m +m}{%
  \only<presentation>{#1}\only<article>{#2}%
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% Gliederung
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% Im Original geht Beamer nur von Parts und Sections aus.
% Bei osgbeamer entspricht jede Lecture einem Kapitel.
% Entsprechend werden die Zähler zusammengelegt.
\RequirePackage{aliascnt}
\mode<article>{\newaliascnt{lecture}{chapter}}
\mode<presentation>{\newaliascnt{chapter}{lecture}}
% Die Zähleranzeige der Sections etc. enthält das Kapitel, außer bei 'standalone'
\IfBool{osgoptionstandalone}{%
  \renewcommand{\thesection}{\arabic{section}}
  \renewcommand{\thesubsection}{\arabic{section}.\arabic{subsection}}
  \renewcommand*{\thedefinition}{\arabic{chapter}.\arabic{definition}}
  \renewcommand*{\theexample}{\arabic{chapter}.\arabic{example}}
}{
  \renewcommand{\thesection}{%
    \thechapter.\arabic{section}%
  }
  \renewcommand{\thesubsection}{
    \thesection.\arabic{subsection}
  }  %% TODO: Appendix
}

% Hook zum Ausführen nach dem Titel
\RequirePackage{apptools}
\gdef\osg@aftertitle{}
\newrobustcmd{\AfterTitle}[1]{
  \gappto{\osg@aftertitle}{#1}
}

\RequirePackage{osgbeamerref}      % (Entfernte) Referenzierung 
\RequirePackage{osgbeamerlanguage} % Sprachbehandlung
\IfBool{osglegacy}{
  % Babel sollte nicht nochmal geladen werden, um einen Optionsclash zu
  % vermeiden
  \ExpandArgs{cc}\NewCommandCopy{osg@original@ver@babel.sty}{ver@babel.sty}
  % Behauptet, dass babel nie geladen wurde. \PreventPackageFromLoading
  % verhindert zwar Laden, aber kein *erneutes* Laden 
  \csundef{ver@babel.sty}
  % Allerdings muss 'csquotes' von 'babel' wissen, und zwar am Ende der Preamble 
  \AddToHook{begindocument/before}[osgbeamer/csq]{\csletcs{ver@babel.sty}{osg@original@ver@babel.sty}}
  \DeclareHookRule{begindocument/before}{osgbeamer/csq}{before}{csquotes}
  % Jetzt wird das Laden von babel durch den Nutzer verhindert
  \PreventPackageFromLoading*[
  \ClassWarning{\classname}{To avoid an option clash, repeated use of package
    'babel' is skipped. Please remove \string\usepackage[...]{babel}}
  ]{babel}
}{}
\RequirePackage{osgbeamerbib}      % Literaturreferenzen

% Jetzt wird das OSG-Beamertheme geladen, das wiederum auf dem TUC-Theme aufbaut
\usetheme{osg}


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% Fonts
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\RequirePackage{fontawesome5}
% LuaLaTeX kann Openface-Fonts, und liefert davon einige mit. Darunter
% auch einige Handschriften-Fonts,so dass eine Installation des
% nonfree Emerald-Packets nicht mehr notwendig ist.
% Allerdings sind die Abstände etwas anders. Es sollte daher bei alten
% Folien/Kapiteln eine Sichtprüfung vorgenommen werden.
\newfontfamily{\scriptfamily}{QTSanDiego}[Scale=1.15]
\DeclareTextFontCommand{\textscript}{\scriptfamily}
\IfBool{osglegacy}{
  \NewCSDeprecatedCommand{ECFJD}{}{\scriptfamily}[use \string\scriptfamily{} or emerald package ]
}{}

% Als Teletype-Schriftart wird in allen Modi DejaVuSansMono gewählt
\mode<presentation>{\setmonofont{DejaVuSansMono}[Scale=MatchLowercase]}
\mode<article>{\setmonofont{DejaVuSansMono}[Scale=MatchLowercase]}
%\newfontfamily\Bera{BeraSansMono}[Scale=0.85]
%\mode<presentation>{\setmonofont{lmmonolt10}[
  % Extension      = .otf,
  % UprightFont    = *-regular,
  % BoldFont       = *-bold,
  % ItalicFont     = *-oblique,
  % BoldItalicFont = *-boldoblique,
  % Scale=MatchLowercase]}
%\usepackage[scaled]{beramono}
%\setmonofont{BeraSansMono}[Scale=MatchLowercase]
%\renewcommand{\ttdefault}{fvm}
% Urls werden in tt-Schrift dargestellt.
\RequirePackage{url}
\def\UrlFont{\ttfamily\upshape}
\Urlmuskip = 0mu plus 1mu

%% aus dem pifont-Paket:
\newcommand{\Pifont}[1]{\fontfamily{#1}\fontencoding{U}\fontseries{m}\fontshape{n}\selectfont}
\newcommand{\Pisymbol}[2]{{\Pifont{#1}\char#2}}
\newcommand{\ding}{\Pisymbol{pzd}}
%%% Farbiger "daraus folgt"-Pfeil
\RequirePackage{xspace}
\newcommand{\follows}{{\usebeamercolor[fg]{structure}\ding{225}}\xspace}
\newcommand{\lfollows}{{\usebeamercolor[fg]{structure}\rotatebox[origin=c]{180}{\ding{225}}}\xspace}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% Fußnoten
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% \afootnote hat nur im Article eine Fußnote gesetzt.
% Das Macro ist nun abgekündigt.
\IfBool{osglegacy}{
  \mode<article>{
    \NewCSDeprecatedCommand{afootnote}{O{}m}{%
      \footnote[#1]{#2}%
    }[use \string\footnote<article>]
  }
  \mode<beamer>{
    \NewCSDeprecatedCommand{afootnote}{O{}m}{}[use \string\footnote<article>]
  }
}{}

% In Beamer werden beim presentation-Mode nur die Fußnoten ausgeblendet, nicht
% die Fußnotenzeichen. Die OSG-Version stellt das IHMO konsistente
% Verhalten her.
% Außerdem sollen Fußnoten *immer* unten in einem Frame erscheinen,
% nicht am Ende von Blöcken. Die aktuelle Beamer-Variante scheint dies
% (entgegen der Doku) zwar per Default zu machen, zur Sicherheit wird
% aber stets die entsprechende Option übergeben. Ein evtl. doppeltes
% Vorkommen von 'frame' ist unkritisch, so dass das Argument nicht
% untersucht werden muss. 
\NewCommandCopy{\original@footnote}{\footnote}
\RenewDocumentCommand{\footnote}{D<>{all} O{} +m}{%
  \only<#1>{\original@footnote[frame,#2]{#3}}%
}

%\RequirePackage{microtype}


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% Farben
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\colorlet{infgreen}{tuccolor@if}
\colorlet{tucgreen}{tuccolor@tuc}
\colorlet{tucwarning}{tuccolor@warning}
\colorlet{tucinfo}{tuccolor@info}
\definecolor{lightgreen}{rgb}{0.824,0.878,0.804}
\definecolor{lightgreen2}{rgb}{0.844,0.918,0.834}
\definecolor{darkgreen}{rgb}{0,0.5,0}
\setbeamercolor{outline}{bg=yellow,fg=black}

%% TODO: Farben von Beamer übernehmen
% \mdfdefinestyle{block}{style=basicblock,backgroundcolor=tuccolor@if!10!white,linecolor=tuccolor@if!80!black,frametitlebackgroundcolor=tuccolor@if!90!white,
%   frametitlefont=\sffamily\color{white}}
% \mdfdefinestyle{alertblock}{style=basicblock,backgroundcolor=tuccolor@warning!20!white,linecolor=tuccolor@warning!80!black,frametitlebackgroundcolor=tuccolor@warning!80!white,
%   frametitlefont=\sffamily}
% \mdfdefinestyle{exampleblock}{style=basicblock,backgroundcolor=black!5!white,linecolor=darkgray,frametitlebackgroundcolor=black!65,
%   frametitlefont=\sffamily\color{white}}

% \IfToggle{osgscript}{
% %   \renewenvironment<>{block}[1]{%
% %     \begin{actionenv}#2\parshape0\osg@footnote@init%
% %     \tikzexternaldisable%
% %     \begin{mdframed}[style=block,frametitle=#1]\makeselectable{\\}
% %     }{\end{mdframed}\osg@footnote@do\end{actionenv}}
  
% % \renewenvironment<>{alertblock}[1]{%
% %   \begin{actionenv}#2\parshape0\osg@footnote@init%
% %     \tikzexternaldisable%
% %     \begin{mdframed}[style=alertblock,frametitle=#1]\makeselectable{\\}
% %     }{\end{mdframed}\osg@footnote@do\end{actionenv}
% % }

% % \renewenvironment<>{exampleblock}[1]{%
% %   \begin{actionenv}#2\parshape0\osg@footnote@init%
% %     \tikzexternaldisable%
% %     \begin{mdframed}[style=exampleblock,frametitle=#1]\makeselectable{\\}
% %     }{\end{mdframed}\osg@footnote@do\end{actionenv}
% % }

% %    \mdtheorem[style=block]{osgdefinition}{Definition}[chapter]
% %    \mdtheorem[style=block]{osgtheorem}{Theorem}[chapter]

% %    %%% TODO: Fußnotenmechanismus anpassen
% %    \renewenvironment{definition}[1][]{%
% %      \parshape0%
% %      \osg@footnote@init%
% %      \tikzexternaldisable%
% %      \begin{osgdefinition}[#1]\makeselectable{\\}
% %      }{\end{osgdefinition}\osg@footnote@do
% %    }
% %    \renewenvironment{theorem}[1][]{%
% %      \parshape0%
% %      \osg@footnote@init%
% %      \tikzexternaldisable%
% %      \begin{osgtheorem}[#1]\makeselectable{\\}
% %      }{\end{osgtheorem}\osg@footnote@do
% %    }
% %    \newcounter{example}[chapter]
% %    \renewenvironment{example}[1][]{%
% %      \refstepcounter{example}%
% %      \parshape0% 
% %      \osg@footnote@init%
% %      \ifstrempty{#1}{\def\extitle{}}{\def\extitle{: #1}}
% %      \begin{exampleblock}{Beispiel \theexample\extitle}\makeselectable{\\}
% %      }{\end{exampleblock}\osg@footnote@do
% %    }
%  }{
%    %\newtheorem{definition}{Definition}[chapter]
%    %\newtheorem{theorem}{Theorem}[chapter]
%    %\newtheorem{lemma}{Lemma}[chapter]
%    \def\th@osgexamplestyle{
%      \def\inserttheoremblockenv{exampleblock}
%    }
%    \def\th@osgblockstyle{ 
%      \def\inserttheoremblockenv{block}
%    }
%    %\theoremstyle{osgexamplestyle}
%    %\newtheorem{example}{Beispiel}[chapter]
%    %\setbeamertemplate{example begin}{}
%    %\setbeamertemplate{example end}{}
% }

\IfBool{osglegacy}{
  \NewCSDeprecatedCommand{tikzanchor}{m m}{%
    \tikz[baseline=(#2.base),remember picture]{\node[outer sep=0,inner sep=0pt](#2){#1};}\xspace%
  }[ use \string\markword]
}{}
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% Textauszeichnungen
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\NewDocumentCommand{\sbf}{D<>{all} +m}{\structure<#1>{\textbf{#2}}}
\NewDocumentCommand{\newdef}{D<>{all} +m}{\structure<#1>{\textbf{#2}}}
\IfBool{osglegacy}{
  \NewCSDeprecatedCommand{ctiny}{D<>{presentation}}{\only<#1>{\tiny}}[use mode spezification]
  \NewCSDeprecatedCommand{cfootnotesize}{D<>{presentation}}{\only<#1>{\footnotesize}}[use mode spezification]
  \NewCSDeprecatedCommand{cscriptsize}{D<>{presentation}}{\only<#1>{\scriptsize}}[use mode spezification]
  \NewCSDeprecatedCommand{csmall}{D<>{presentation}}{\only<#1>{\small}}[use mode spezification]
  \NewCSDeprecatedCommand{cnormalsize}{D<>{presentation}}{\only<#1>{\normalsize}}[use mode spezification]
}{}
\RequirePackage{lua-ul}
\let\uline=\underLine
% \outline unterscheidet sich im den Modi: In der Presentation ist es
% Textmarker, im Article unterstrichen
\mode<article>{
  \newunderlinetype\beginUnderWavy[\number\dimexpr1ex]{\cleaders\hbox{%
      \setlength\unitlength{.3ex}%
      \begin{picture}(4,0)(0,1)
          \thicklines
          % \color{red}%
          \qbezier(0,0)(1,1)(2,0)
          \qbezier(2,0)(3,-1)(4,0)
      \end{picture}%
    }}
  \NewDocumentCommand\outline{D<>{all}+m}{\alt<#1>{\underline{#2}}{#2}}
}
\mode<presentation>{
  \NewDocumentCommand\outline{D<>{all}+m}{\alt<#1>{\highLight{#2}}{\highLight[white]{#2}}} % Die white-Version sorgt für
  % identische Abstände.
  % ToDo: \highLight anpassen, dass der Durchschuss nicht geändert wird.
}
% Auch \stess (war: \grave) ist modespezifisch (ToDo: Soll das so bleiben?)
\mode<presentation>{\NewDocumentCommand\stress{D<>{all} m}{{\only<#1>{\color{structure}}{#2}}}}
\mode<article>{\NewDocumentCommand\stress{D<>{all} m}{\emph<#1>{#2}}}
% \grave wird jetzt durch amsmath als mathematischer Akzent definiert.
% Mit legacy-Option wird dies überschrieben
\IfBool{osglegacy}{
  \AddToHook{begindocument}{
    \RenewCSDeprecatedCommand{grave}{d<>m}{%
      \IfNoValueTF{#1}{%
        \textcolor{structure}{#2}%
      }{%
        \only<#1>{\textcolor{structure}}{#2}%
      }}[use \string\stress]
  }
}{}
\RequirePackage{calc}
\NewDocumentCommand\sourceref{O{\ldeen{Quelle}{Source}} m}{%
  \begin{description}[style=sameline]\fontsize{6pt}{2pt}\selectfont
  \item[\textbf{#1:}] \stress{#2}
  \end{description}}
  %\par{\fontsize{6pt}{2pt}\selectfont\textbf{#1}:: \stress{#2}}}
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% Columns
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Vereinfachtes Spaltenmanagement für zwei Spalten:
%% twocolumns nimmt zwei optionale Argumente (Reihenfolge egal):
%% - vertikale Ausrichtung {c|b|t|T}
%% - Anteil, den die erste Spalte einnimmt. 

\newlength{\osgleftcolwid}
\newlength{\osgrightcolwid}

\ExplSyntaxOn

\NewDocumentCommand{\IfNumberTF}{mmm}
 {
  % regex from https://stackoverflow.com/a/23872060/923955
  % with modifications for expl3 and for adding a unit
  \regex_match:nnTF
   { \A [+\-]? ((\d+(\.\d*)?)|(\.\d+)) \Z} % regex
   { #1 } % test string
   { #2 } % true text
   { #3 } % false text
 }

\ExplSyntaxOff

\NewDocumentCommand{\twocolparam}{>{\SplitList{,}} m}{
  \def\osgtcfcwid{0.5}%    Falls keine Länge angegeben wird
  \def\osgtcalignparam{c}% Falls kein Alignmentparameter angegeben wird
  \def\parseandsetarguments##1{%
    \IfNumberTF{##1}{%
      \def\osgtcfcwid{##1}%
    }{%
      \def\osgtcalignparam{##1}%
    }%
  }%
  \ProcessList{#1}{\parseandsetarguments}% W
}

 \newenvironment<>{twocolumns}[1][t,0.475]{
  \twocolparam{#1} 
  \setlength{\osgleftcolwid}{\fpeval{\osgtcfcwid*0.95}\textwidth}
  \setlength{\osgrightcolwid}{0.95\textwidth}
  \addtolength{\osgrightcolwid}{-\osgtcfcwid\textwidth}
  \alt#2{\def\nextcolumn{\column{\osgrightcolwid}}}{\def\nextcolumn{\par}}
  \begin{columns}#2[\osgtcalignparam]\column{\osgleftcolwid}
  }{
  \end{columns}%\undef{\osgleftcolwid}\undef{\osgrightcolwid}
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% Deko
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\RequirePackage{twemojis}
\newcommand{\makesmiley}[2]{\csgdef{osgsmiley#1}{\raisebox{-.2ex}{\texttwemoji{#2}}}}
\makesmiley{:-)}{1f60a} % happy 
\makesmiley{:-D}{1f600} % laugh
\makesmiley{:-|}{1f62c}% angry
\makesmiley{:-()}{1f615}% sad 
\makesmiley{:-P}{1f61b} % tongue
\makesmiley{;-)}{1f609} % wink 
\makesmiley{:-o}{1f62e} % astonished
\makesmiley{B-)}{1f60e} % cool
\newcommand{\smiley}[1]{\csuse{osgsmiley#1}}
%\let\osgsmiley=\smiley

% Erstellt einen tikz-Anker (Name ist erster Parameter) um den
% gegebenen Text (2. Parameter), auf den später referenziert werden
% kann.
\newif\ifosgmarkmm%
\newcommand{\markword}[2]{%
  \relax\ifmmode% Ist die Markierung im Mathe-Modus?
  \osgmarkmmtrue\else\osgmarkmmfalse\fi%
  \ifdef{\tikzexternalize}{\tikzset{external/export next=false}}{}% deaktiviere tikz-Externalisierung
  \tikz[remember picture, baseline]\node[anchor=text,inner sep=0pt](#1){\ifosgmarkmm$#2$\else#2\fi};}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% Grafiken
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
\RequirePackage{pgf}
% Horizontal zentriertes Bild. Der optionale Parameter enthält die
% Breite (default: 0.9\textwidth). Es können zwei durch Komma
% getrennte Werte angegeben werden: Der erste gilt dann für
% den presentation-Mode, der zweite für den article-Mode.
\newcommand{\osg@centerpic}[2][]{
  \def\parsewidth##1,##2,{\dimdef{\pw}{##1}\dimdef\aw{##2}}
  \edef\x{\noexpand\in@{,}{#1}}\x
  \ifin@
    \parsewidth#1,\relax
  \else
    \dimdef\pw{#1}
    \dimdef\aw{#1}
   \fi
  \only<presentation>{\centerline{\includegraphics[width=\pw]{#2}}}
  \only<article>{\centerline{\includegraphics[width=\aw]{#2}}}
}
\NewDocumentCommand\centerpic{D<>{all} O{0.9\textwidth} m}{%
  \only<#1>{\osg@centerpic[#2]{#3}}
}
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% Anhang
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Anhang gibt es in zwei "Geschmacksrichtungen". Zum einen kann eine einzelne
% Vorlesung einen Anhang haben, zum anderen können ganze Vorlesungen zum
% Anhang erklärt werden, was i.d.R. nur im Zusammenhang mit Skripten sinnvoll
% ist.
% Um beide Varianten zu unterscheiden wird geprüft, ob die \appendix-Anweisung
% in der Preamble oder im Dokument steht.
\AtAppendix{%
  \ifx\@onlypreamble\@notprerr
   \renewcommand{\thesection}{\appendixname~\Alph{section}:}
   \renewcommand{\thesubsection}{\thesection.\arabic{subsection}}
    \setcounter{section}{0}
  \else
    \renewcommand{\thesection}{\thechapter.\arabic{section}}
   \renewcommand{\thesubsection}{\thesection.\arabic{subsection}}
  \fi
}


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% Anmerkungen
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\mode<article>{\def\Note#1{}}
\mode<presentation>{\def\Note#1{\beamer@inframenote[item]{#1}}}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% Titeldaten
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\mode<article>{
  % Erlaube optionale Argumente für \author und \date
  \global\let\@osg@original@author=\author
  \global\let\@osg@original@title=\title
 
  \RenewDocumentCommand\author{O{#2} m}{
    \gdef\osgshortauthor{#1}
    \gdef\osgauthor{#2}
    \gdef\@author{#2}
  }
  \RenewDocumentCommand\title{O{#2} m}{
    \gdef\osgshorttitle{#1}
    \gdef\osgtitle{#2}
    \gdef\@title{#2}
  }
  \gdef\lehrveranstaltung{\title}
  \RenewDocumentCommand\date{O{#2} m}{
    \gdef\@date{#2}
    \gdef\osgdate{#2}
    \gdef\osgshortdate{#1}
  }
  \gdef\lehrveranstaltung{\title}
}
\mode<presentation>{
  \gdef\lehrveranstaltung{\subtitle}
}

\let\event=\lehrveranstaltung
\let\course=\lehrveranstaltung

\osg@titlematterhook

\let\osg@origina@Roman=\Roman
\renewcommand{\Roman}[1]{%
  \ifnum\value{#1}=0\relax0\else\osg@origina@Roman{#1}\fi}

\NewDocumentCommand\DebugFont{}{Family: \f@family\  with size: \f@size.}
% %%% Local Variables:
% %%% mode: latex
% %%% End:
