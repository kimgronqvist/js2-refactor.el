;;; js2-refactor.el --- The beginnings of a JavaScript refactoring library in emacs.

;; Copyright (C) 2012 Magnar Sveen

;; Author: Magnar Sveen <magnars@gmail.com>
;; Keywords: conveniences

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This is a collection of small refactoring functions to further the idea of a
;; JavaScript IDE in Emacs that started with js2-mode.

;; ## Installation

;; Start by installing the dependencies:

;;  * js2-mode https://github.com/mooz/js2-mode/
;;  * dash https://github.com/magnars/dash.el
;;  * multiple-cursors https://github.com/magnars/multiple-cursors.el

;; It is also recommended to get
;; [expand-region](https://github.com/magnars/expand-region.el) to more easily mark
;; vars, method calls and functions for refactorings.

;; Then add this to your emacs settings:

;;     (require 'js2-refactor)

;; Note: I am working on a smoother installation path through package.el,
;; but I haven't had the time to whip this project into that sort of
;; structure - yet.

;; ## Usage

;; All refactorings start with `C-c C-m` and then a two-letter mnemonic shortcut.

;;  * `ef` is `extract-function`: Extracts the marked expressions out into a new named function.
;;  * `em` is `extract-method`: Extracts the marked expressions out into a new named method in an object literal.
;;  * `ip` is `introduce-parameter`: Changes the marked expression to a parameter in a local function.
;;  * `lp` is `localize-parameter`: Changes a parameter to a local var in a local function.
;;  * `eo` is `expand-object`: Converts a one line object literal to multiline.
;;  * `co` is `contract-object`: Converts a multiline object literal to one line.
;;  * `eu` is `expand-function`: Converts a one line function to multiline (expecting semicolons as statement delimiters).
;;  * `cu` is `contract-function`: Converts a multiline function to one line (expecting semicolons as statement delimiters).
;;  * `ea` is `expand-array`: Converts a one line array to multiline.
;;  * `ca` is `contract-array`: Converts a multiline array to one line.
;;  * `wi` is `wrap-buffer-in-iife`: Wraps the entire buffer in an immediately invoked function expression
;;  * `ig` is `inject-global-in-iife`: Creates a shortcut for a marked global by injecting it in the wrapping immediately invoked function expression
;;  * `ag` is `add-to-globals-annotation`: Creates a `/*global */` annotation if it is missing, and adds the var at point to it.
;;  * `ev` is `extract-var`: Takes a marked expression and replaces it with a var.
;;  * `iv` is `inline-var`: Replaces all instances of a variable with its initial value.
;;  * `rv` is `rename-var`: Renames the variable on point and all occurrences in its lexical scope.
;;  * `vt` is `var-to-this`: Changes local `var a` to be `this.a` instead.
;;  * `ao` is `arguments-to-object`: Replaces arguments to a function call with an object literal of named arguments. Requires yasnippets.
;;  * `3i` is `ternary-to-if`: Converts ternary operator to if-statement.
;;  * `sv` is `split-var-declaration`: Splits a `var` with multiple vars declared, into several `var` statements.
;;  * `uw` is `unwrap`: Replaces the parent statement with the selected region.

;; There are also some minor conveniences bundled:

;;  * `C-S-down` and `C-S-up` moves the current line up or down. If the line is an
;;    element in an object or array literal, it makes sure that the commas are
;;    still correctly placed.

;; ## Todo

;; A list of some wanted improvements for the current refactorings.

;;  * expand- and contract-array: should work recursively with nested object literals and nested arrays.
;;  * expand- and contract-function: should deal better with nested object literals, array declarations, and statements terminated only by EOLs (without semicolons).
;;  * wrap-buffer-in-iife: should skip comments and namespace initializations at buffer start.
;;  * extract-variable: could end with a query-replace of the expression in its scope.

;; ## Contributions

;; * [Matt Briggs](https://github.com/mbriggs) contributed `js2r-add-to-globals-annotation`

;; Thanks!

;; ## Contribute

;; This project is still in its infancy, and everything isn't quite sorted out
;; yet. If you're eager to contribute, please add an issue here on github and we
;; can discuss your changes a little before diving into the elisp. :-)

;; To fetch the test dependencies:

;;     $ cd /path/to/multiple-cursors
;;     $ git submodule init
;;     $ git submodule update

;; Run the tests with:

;;     $ ./util/ecukes/ecukes features

;;; Code:

(require 'js2-mode)
(require 'js2r-helpers)
(require 'js2r-formatting)
(require 'js2r-iife)
(require 'js2r-vars)
(require 'js2r-functions)
(require 'js2r-wrapping)
(require 'js2r-conditionals)
(require 'js2r-conveniences)
(require 'js2r-paredit)

;;; Settings ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar js2r-use-strict nil
  "When non-nil, js2r inserts strict declarations in IIFEs.")

;;; Keybindings ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun js2r--add-keybindings (key-fn)
  (define-key js2-mode-map (funcall key-fn "eo") 'js2r-expand-object)
  (define-key js2-mode-map (funcall key-fn "co") 'js2r-contract-object)
  (define-key js2-mode-map (funcall key-fn "eu") 'js2r-expand-function)
  (define-key js2-mode-map (funcall key-fn "cu") 'js2r-contract-function)
  (define-key js2-mode-map (funcall key-fn "ea") 'js2r-expand-array)
  (define-key js2-mode-map (funcall key-fn "ca") 'js2r-contract-array)
  (define-key js2-mode-map (funcall key-fn "wi") 'js2r-wrap-buffer-in-iife)
  (define-key js2-mode-map (funcall key-fn "ig") 'js2r-inject-global-in-iife)
  (define-key js2-mode-map (funcall key-fn "ev") 'js2r-extract-var)
  (define-key js2-mode-map (funcall key-fn "iv") 'js2r-inline-var)
  (define-key js2-mode-map (funcall key-fn "rv") 'js2r-rename-var)
  (define-key js2-mode-map (funcall key-fn "vt") 'js2r-var-to-this)
  (define-key js2-mode-map (funcall key-fn "ag") 'js2r-add-to-globals-annotation)
  (define-key js2-mode-map (funcall key-fn "sv") 'js2r-split-var-declaration)
  (define-key js2-mode-map (funcall key-fn "ef") 'js2r-extract-function)
  (define-key js2-mode-map (funcall key-fn "em") 'js2r-extract-method)
  (define-key js2-mode-map (funcall key-fn "ip") 'js2r-introduce-parameter)
  (define-key js2-mode-map (funcall key-fn "lp") 'js2r-localize-parameter)
  (define-key js2-mode-map (funcall key-fn "tf") 'js2r-toggle-function-expression-and-declaration)
  (define-key js2-mode-map (funcall key-fn "ao") 'js2r-arguments-to-object)
  (define-key js2-mode-map (funcall key-fn "uw") 'js2r-unwrap)
  (define-key js2-mode-map (funcall key-fn "wl") 'js2r-wrap-in-for-loop)
  (define-key js2-mode-map (funcall key-fn "3i") 'js2r-ternary-to-if)
  (define-key js2-mode-map (funcall key-fn "lt") 'js2r-log-this)
  (define-key js2-mode-map (funcall key-fn "sl") 'js2r-forward-slurp)
  (define-key js2-mode-map (funcall key-fn "ba") 'js2r-forward-barf)
  (define-key js2-mode-map (kbd "<C-S-down>") 'js2r-move-line-down)
  (define-key js2-mode-map (kbd "<C-S-up>") 'js2r-move-line-up))

;;; Menu ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(require 'easymenu)

(defvar js2r--menu nil
  "Holds the menu.")

(easy-menu-define js2r--menu
  js2-mode-map
  "Menu used when js2r is active."
  '("Refactor"
    ["Log This" js2r-log-this
     :help "Adds a console.log statement for what is at point (or region)."]
    ["Extract Function" js2r-extract-function
     :help "Extracts the marked expressions out into a new named function."]
    ["Extract Method" js2r-extract-method
     :help "Extracts the marked expressions out into a new named method in an object literal."]
    ["Introduce Parameter" js2r-introduce-parameter
     :help "Changes the marked expression to a parameter in a local function."]
    ["Localize Parameter" js2r-localize-parameter
     :help "Changes a parameter to a local var in a local function."]
    ["Wrap Buffer In Iife" js2r-wrap-buffer-in-iife
     :help "Wraps the entire buffer in an immediately invoked function expression"]
    ["Inject Global In Iife" js2r-inject-global-in-iife
     :help "Creates a shortcut for a marked global by injecting it in the wrapping immediately invoked function expression"]
    ["Add To Globals Annotation" js2r-add-to-globals-annotation
     :help "Creates a /*global */ annotation if it is missing, and adds the var at point to it."]
    ["Arguments To Object" js2r-arguments-to-object
     :help "Replaces arguments to a function call with an object literal of named arguments. Requires yasnippets."]
    ["Ternary To If" js2r-ternary-to-if
     :help "Converts ternary operator to if-statement."]
    "----"
    ("Expand / Contract"
     ["Expand Object" js2r-expand-object
      :help "Converts a one line object literal to multiline."]
     ["Contract Object" js2r-contract-object
      :help "Converts a multiline object literal to one line."]
     ["Expand Function" js2r-expand-function
      :help "Converts a one line function to multiline (expecting semicolons as statement delimiters)."]
     ["Contract Function" js2r-contract-function
      :help "Converts a multiline function to one line (expecting semicolons as statement delimiters)."]
     ["Expand Array" js2r-expand-array
      :help "Converts a one line array to multiline."]
     ["Contract Array" js2r-contract-array
      :help "Converts a multiline array to one line."])
    ("Var"
     ["Extract Var" js2r-extract-var
      :help "Takes a marked expression and replaces it with a var."]
     ["Inline Var" js2r-inline-var
      :help "Replaces all instances of a variable with its initial value."]
     ["Rename Var" js2r-rename-var
      :help "Renames the variable on point and all occurrences in its lexical scope."]
     ["Var To This" js2r-var-to-this
      :help "Changes local var a to be this.a instead."]
     ["Split Var Declaration" js2r-split-var-declaration
      :help "Splits a var with multiple vars declared, into several var statements."]
     )
    ("Paredit"
     ["Unwrap" js2r-unwrap
      :help "Replaces the parent statement with the selected region."]
     ["Forward Slurp" js2r-forward-slurp
      :help "Moves the next statement into current function, if-statement, for-loop or while-loop."]
     ["Forward Barf" js2r-forward-barf
      :help "Moves the last child out of current function, if-statement, for-loop or while-loop."])))

;;;###autoload
(defun js2r-add-keybindings-with-prefix (prefix)
  (js2r--add-keybindings (-partial 'js2r--key-pairs-with-prefix prefix)))

;;;###autoload
(defun js2r-add-keybindings-with-modifier (modifier)
  (js2r--add-keybindings (-partial 'js2r--key-pairs-with-modifier modifier)))

(provide 'js2-refactor)
;;; js2-refactor.el ends here
