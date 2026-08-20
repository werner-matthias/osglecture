# OLLM

OLLM (OSG LaTeX Lecture Maker) is the build frontend of the `osglecture`
bundle. It selects document and language variants and delegates individual
LaTeX builds to `latexmk`.

## For Users of OSGBeamer
There are a few conceptual differences of the user's perception of the build model
of OSGLecture in comparision to OSGBeamer:

- The configuration format has changed, from Perl to TOML. Accordingly, the configuration file
  not ollmconfig.pl anymore, but ollmconfig.toml. In addition, there are more places to configure
  things. 
  Old Perl-based  configuration can be converted by `ollm convertconfig`. However, a follow-up check
  is recommended.
- Resulting artifacts (pdfs) can not be found in the unit directories, but in subdirectories
  of `.osglecture/build`, which can be found in the project root. This has two advantages:
  - input materials are clearly sperated from output materials, which improves the overall clarity
  - in case of an invalid state, deleting whole output directories is a last resort that can be applied without 
    the danger of removing 

## Installation

Run these commands from this directory:

```sh
l3build check
l3build -full install
```

## Documentation
Please read `ollm-en.pdf` or `ollm-de.pdf` for documentation English or German.

## TL;DR: Few Examples

### Build Script Chapter in English
```sh
ollm build script --language=en 
````
or
```sh
ollm script lang=en
```
### Check Installation and Environment
```sh
ollm doctor
```
### Getting Help
```sh
ollm --help
```
