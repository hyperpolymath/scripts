; SPDX-License-Identifier: MPL-2.0
;; guix.scm — GNU Guix package definition for scripts
;; Usage: guix shell -f guix.scm

(use-modules (guix packages)
             (guix build-system gnu)
             (guix licenses))

(package
  (name "scripts")
  (version "0.1.0")
  (source #f)
  (build-system gnu-build-system)
  (synopsis "scripts")
  (description "scripts — part of the hyperpolymath ecosystem.")
  (home-page "https://github.com/hyperpolymath/scripts")
  (license mpl2.0))
