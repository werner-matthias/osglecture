# ltxtalk-themes API Reference

## Overview

The ltxtalk-themes system provides a flexible, accessible theme engine for the ltx-talk document class. Themes are built on a slot-based architecture using LaTeX3 coffins internally, but this complexity is completely hidden from users.

## Core Commands

### Theme Management

| Command | Description |
|---------|-------------|
| `\useltxtalktheme{name}` | Activate a theme |
| `\RegisterLTXTalkTheme{name}{setup}` | Register a new theme (for developers) |

### Layout Configuration

```latex
\ltxtalksetup{
  header = true/false,
  header-height = dimension,
  header-rows = integer,
  left-margin = true/false,
  right-margin = true/false,
  footer = true/false,
  footer-height = dimension,
  margin-width = dimension,
}
```

### Color Configuration

```latex
\setltxtalkcolors{
  primary = {HTML}{2B3A67},
  secondary = {HTML}{496A81},
  accent = {HTML}{66999B},
  text = {HTML}{333333},
  background = {HTML}{FFFFFF},
}
```

### Slot Definition
```latex
\defineltxtalkslot{slot-name}{area}{type}{accessibility-options}

% Example:
\defineltxtalkslot{my-title}{header}{frametitle}{
  role = heading,
  heading-level = 2
}
```

### Slot Positioning
```latex
\positionltxtalkslot{slot-name}{x-pos}{y-pos}{width}{height}

% Example:
\positionltxtalkslot{my-title}{center}{0.5cm}{0.8\paperwidth}{1.5cm}
```

### Slot Styling
```latex
\styleltxtalkslot{slot-name}{
  font = \Large\bfseries,
  color = ltxtalk-primary,
  frame = bottom,
  rule-color = ltxtalk-accent,
  rule-thick = 2pt,
  padding = 5pt,
  align = center,
  background = none,
}
```

### Area Decoration
```latex
\decorateltxtalkarea{header}{
  frame = bottom,
  rule-color = ltxtalk-accent,
  rule-thickness = 4pt,
  background = ltxtalk-primary!5,
  shadow = true,
}
```

### Available Slot Types

| Type            | Description        | Default Role.    |
|-----------------|--------------------|------------------| 
| `frametitle`    | Frame title        | heading (H2)     | 
| `framesubtitle` | Frame subtitle     | heading (H3)     | 
| `title`         | Presentation title | heading (H1)     | 
| `section`       | Current section    | heading (H2)     | 
| `subsection`    | Current subsection | heading (H3)     | 
| `author`        | Author name        | note             | 
| `date`          | Date               | note             | 
| `institute`     | Institute name     | note             | 
| `pagenumber`    | Page number        | navigation       | 
| `logo`          | Logo               | graphic artifact |
| `custom`        | User-defined       | artifact         | 

### Available Areas

| Area.     | Description           |
|-----------|-----------------------| 
| `header`  | Top of the frame      | 
| `left`.   | Left margin           | 
| `content` | Main content area     | 
| `right`.  | Right margin          | 
| `footer`  | Bottom of the frame.  | 

### Accessibility Options
```latex
\defineltxtalkslot{name}{area}{type}{
  role = heading|artifact|navigation|content|note,
  heading-level = 1|2|3,
  alt-text = "Description",
  continuation-text = "(cont.)",
  continuation-mode = explicit|implicit,
}
```

### Title Placement
```latex
\setltxtalktitleplacement{
  frametitle = content|header|both,
  section = header|none,
}
```

### Best Practices
1. Always provide accessibility roles for slots
2. Use `artifact` role for decorative elements
3. Set appropriate heading levels for titles
4. Test with screen readers
5. Provide alt-text for logos and images
