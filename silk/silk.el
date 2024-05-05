;;; silk --- Sil game interface -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:
;;;; Library imports
(require 's)
(require 'f)
(require 'dash)
(require 'ht)

;;;; Customization groups
(defgroup silk nil
  "Sil interface."
  :group 'applications)

(defgroup silk-faces nil
  "Faces for `silk'."
  :group 'silk
  :group 'faces)

;;;; Faces

;;;; Configuration variables
(defcustom silk/process-buffer " *silk-process*"
  "Name of buffer used to store intermediate process output."
  :type '(string)
  :group 'silk)

(defcustom silk/sil-path (f-join (f-dirname (f-dirname (symbol-file 'silk/process-buffer))) "sil")
  "Path to Sil executable."
  :type '(string)
  :group 'silk)

(defcustom silk/process-error-buffer " *silk-process-error*"
  "Name of buffer used to store stderr output from Sil."
  :type '(string)
  :group 'silk)

(defcustom silk/log-buffer " *silk-log*"
  "Name of buffer used to store the event log."
  :type '(string)
  :group 'silk)

(defcustom silk/map-buffer "*silk-map*"
  "Name of buffer used to display the map."
  :type '(string)
  :group 'silk)

(defcustom silk/note-buffer "*silk-note*"
  "Name of buffer used to display the note."
  :type '(string)
  :group 'silk)

;;;; Constants
(defconst silk//directions
  '((northwest . "7")
    (north . "8")
    (northeast . "9")
    (west . "4")
    (east . "6")
    (southwest . "1")
    (south . "2")
    (southeast . "3"))
  "Alist mapping direction symbols to direction strings.")

(defconst silk//event-handlers
  (list
   (cons 'note (lambda (d) (silk//update-note (car d))))
   (cons 'note-item (lambda (d) (silk//update-note (car d))))
   (cons 'bell (lambda (d) (silk//update-note (car d))))
   (cons 'map #'silk//update-map)
   ))

;;;; State variables

;;;; Major modes
(define-derived-mode silk/map-mode special-mode "Silk"
  "Mode for displaying the Sil map."
  :group 'silk)

(define-key silk/map-mode-map (kbd ".") (lambda () (interactive) (silk//send-input "5")))
(define-key silk/map-mode-map (kbd "h") (lambda () (interactive) (silk/move 'west)))
(define-key silk/map-mode-map (kbd "j") (lambda () (interactive) (silk/move 'south)))
(define-key silk/map-mode-map (kbd "k") (lambda () (interactive) (silk/move 'north)))
(define-key silk/map-mode-map (kbd "l") (lambda () (interactive) (silk/move 'east)))
(define-key silk/map-mode-map (kbd "y") (lambda () (interactive) (silk/move 'northwest)))
(define-key silk/map-mode-map (kbd "u") (lambda () (interactive) (silk/move 'northeast)))
(define-key silk/map-mode-map (kbd "b") (lambda () (interactive) (silk/move 'southwest)))
(define-key silk/map-mode-map (kbd "n") (lambda () (interactive) (silk/move 'southeast)))

(define-key silk/map-mode-map (kbd "H") (lambda () (interactive) (silk/run 'west)))
(define-key silk/map-mode-map (kbd "J") (lambda () (interactive) (silk/run 'south)))
(define-key silk/map-mode-map (kbd "K") (lambda () (interactive) (silk/run 'north)))
(define-key silk/map-mode-map (kbd "L") (lambda () (interactive) (silk/run 'east)))
(define-key silk/map-mode-map (kbd "Y") (lambda () (interactive) (silk/run 'northwest)))
(define-key silk/map-mode-map (kbd "U") (lambda () (interactive) (silk/run 'northeast)))
(define-key silk/map-mode-map (kbd "B") (lambda () (interactive) (silk/run 'southwest)))
(define-key silk/map-mode-map (kbd "N") (lambda () (interactive) (silk/run 'southeast)))

(define-derived-mode silk/note-mode special-mode "Silk"
  "Mode for displaying Sil notes."
  :group 'silk)

(define-derived-mode silk/charsheet-mode special-mode "Silk"
  "Mode for displaying the Sil character sheet."
  :group 'silk
  (hl-line-mode))

(define-derived-mode silk/inventory-mode tabulated-list-mode "Silk"
  "Mode for displaying Sil inventory information."
  :group 'silk
  (hl-line-mode))

;;;; Utility functions
(defun silk//wipe-buffer ()
  "Erase the current buffer, including read-only text."
  (let ((inhibit-read-only t))
    (delete-all-overlays)
    (set-text-properties (point-min) (point-max) nil)
    (erase-buffer)))

(defun silk//write (text &optional face)
  "Write TEXT to the current buffer and apply FACE."
  (let ((text-final (if face (propertize text 'face face) text)))
    (insert text-final)))

(defun silk//write-line (line &optional face)
  "Write LINE and a newline to the current buffer and apply FACE."
  (silk//write (concat line "\n") face))

(defun silk//clean-string (s)
  "Remove special characters from S."
  (replace-regexp-in-string "[^\n[:print:]]" "" (format "%s" s)))

(defun silk//write-log (line &optional face)
  "Write LINE to the log buffer and apply FACE."
  (with-current-buffer (get-buffer-create silk/log-buffer)
    (goto-char (point-max))
    (silk//write-line (silk//clean-string line) face)
    (goto-char (point-max))))

;;;; Game process communication and control
(defun silk//handle-message (msg)
  "Handle the message MSG."
  (let* ((ev (car msg))
         (body (cdr msg))
         (handler (alist-get ev silk//event-handlers nil nil #'equal)))
    (silk//write-log (format "%S" msg))
    (if handler
        (funcall handler body)
      (silk//write-log (format "Unknown incoming event: %S" ev)))))

(defun silk//get-complete-line ()
  "Kill a line followed by a newline if it exists, and nil otherwise."
  (let ((l (thing-at-point 'line t)))
    (if (and l (s-contains? "\n" l))
        (progn
          (delete-region (line-beginning-position) (line-beginning-position 2))
          l)
      nil)))
(defun silk//handle-lines ()
  "Call `silk//handle-message' on every complete line of the current buffer."
  (let ((l (silk//get-complete-line)))
    (when (and l (not (s-blank? l)))
      (silk//handle-message (car (read-from-string (silk//clean-string l))))
      (silk//handle-lines))))
(defun silk//process-filter (proc data)
  "Process filter for Sil PROC and DATA."
  (with-current-buffer (get-buffer-create silk/process-buffer)
    (when (not (marker-position (process-mark proc)))
      (set-marker (process-mark proc) (point-max)))
    (goto-char (process-mark proc))
    (insert data)
    (set-marker (process-mark proc) (point))
    (goto-char (point-min))
    (silk//handle-lines)))

(defun silk//send-input (inp)
  "Send INP to the Sil process."
  (process-send-string
   "silk"
   (s-concat inp "\n")))

(defun silk/kill ()
  "Stop the Sil process."
  (when (process-live-p (get-process "silk"))
    (delete-process "silk")))

(defun silk/start ()
  "Start the Sil process."
  (silk/kill)
  (let ((default-directory (f-dirname silk/sil-path)))
    (make-process
     :name "silk"
     :command (list silk/sil-path)
     :buffer nil
     :stderr silk/process-error-buffer
     :filter #'silk//process-filter)))

(defun silk/move (dir)
  "Send a move command (in DIR)."
  (when-let ((dstr (alist-get dir silk//directions)))
    (silk//send-input dstr)))

(defun silk/run (dir)
  "Send a run command (in DIR)."
  (when-let ((dstr (alist-get dir silk//directions)))
    (silk//send-input (s-concat "." dstr))))

;;;; Updating buffers
(defun silk//update-note (note)
  "Update the note buffer to display NOTE."
  (let ((trimmed (s-join " " (s-split " " note t))))
    (with-current-buffer (get-buffer-create silk/note-buffer)
      (silk/note-mode)
      (setq-local buffer-read-only nil)
      (silk//wipe-buffer)
      (silk//write trimmed)
      (setq-local buffer-read-only t))))

(defun silk//update-map (map)
  "Update map note buffer to display MAP."
  (let ((width (car map))
        ;; (height (cadr map))
        (cells (caddr map)))
    (with-current-buffer (get-buffer-create silk/map-buffer)
      (silk/map-mode)
      (setq-local buffer-read-only nil)
      (silk//wipe-buffer)
      (--each (-zip-pair (-iota (length cells)) cells)
        (silk//write (cadr it))
        (when (= 0 (% (car it) width))
          (silk//write "\n"))
        )
      (setq-local buffer-read-only t))))

(provide 'silk)
;;; silk.el ends here
