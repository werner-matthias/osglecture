# OSG Lecture

[![Linux](https://github.com/werner-matthias/osglecture/actions/workflows/tests-linux.yml/badge.svg)](https://github.com/werner-matthias/osglecture/actions/workflows/tests-linux.yml)
[![macOS](https://github.com/werner-matthias/osglecture/actions/workflows/tests-macos.yml/badge.svg)](https://github.com/werner-matthias/osglecture/actions/workflows/tests-macos.yml)
[![Windows](https://github.com/werner-matthias/osglecture/actions/workflows/tests-windows.yml/badge.svg)](https://github.com/werner-matthias/osglecture/actions/workflows/tests-windows.yml)

LaTeX bundle for generating lecture materials at the Operating Systems Group at the TU Chemnitz.

Currently, the following packages are included:

* The **osglecture** class to generate different materials (slides, script) from a common source (`./osglecture`)
* **OSG LaTeX Lecture Maker**: a latexmk-based build script to support creation and deploying of lecture materials (`./ollm`)
* **osglecture-modes**: generalized portable document modes (`./osglecture-modes`)
* **langselect**: support the generation of different language versions from a common source (`./langselect`)
* **tagpax**:  semantic import of tagged PDFs (`./tagpax`)
* **ltxtalk-theme**: theme engine to allow easy and flexible design of themes for ltx-talk (`./lttheme`)
* **ltxtalk-theme-tuc-2019**: presentation theme of TU Chemnitz for ltx-talk (`./lttheme-tuc-2019`)
* **osgdoc**: support for documentation (`./osgdoc`) 

## Installation
```
l3build check
l3build install
ollm doctor
```
 
## Compatibility
In total, the bundle requires an up-to-date TeX installation.
However, few packages run with older distributions.
The following table show the compatibility with the TeXLive/MacTeX distributions
of the last years.

| Package          | 2024 | 2025 | 2026 |
|------------------|:----:|:----:|:----:|
| osglecture       | :x:  | :+1: | :+1: |
| ollm             | :x:  | :+1: | :+1: |
| osglecuture-mode[^1] | :+1: | :+1: | :+1: |
| langselect       | :+1: | :+1: | :+1: |
| tagpax           | :+1: | :+1: | :+1: |
| lttheme          | :x:  | :x:  | :+1: |
| ltheme-TUC2019   | :x:  | :x:  | :+1: |
| osgdoc           | :+1: | :+1: | :+1: |

[^1]: With ltx-talk bridge 2026 only