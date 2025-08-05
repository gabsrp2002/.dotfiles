# latexmkrc
$pdflatex = 'lualatex -file-line-error %O %S';
if ($^O =~ /linux/ ) {
    $pdf_previewer = 'start mupdf';
    $pdf_update_method = 2;
    $pdf_update_signal = 'SIGHUP';
}
