#' Create tables in LaTeX, HTML, Markdown and reStructuredText
#'
#' This is a very simple table generator. It is simple by design. It is not
#' intended to replace any other R packages for making tables.
#'
#' Missing values (\code{NA}) in the table are displayed as \code{NA} by
#' default. If you want to display them with other characters, you can set the
#' option \code{knitr.kable.NA}, e.g. \code{options(knitr.kable.NA = '')} to
#' hide \code{NA} values.
#' @param x An R object, typically a matrix or data frame.
#' @param format A character string. Possible values are \code{latex},
#'   \code{html}, \code{markdown}, \code{pandoc}, and \code{rst}; this will be
#'   automatically determined if the function is called within \pkg{knitr}; it
#'   can also be set in the global option \code{knitr.table.format}. If
#'   \code{format} is a function, it must return a character string.
#' @param digits Maximum number of digits for numeric columns, passed to
#'   \code{round()}. This can also be a vector of length \code{ncol(x)}, to set
#'   the number of digits for individual columns.
#' @param row.names Logical: whether to include row names. By default, row names
#'   are included if \code{rownames(x)} is neither \code{NULL} nor identical to
#'   \code{1:nrow(x)}.
#' @param col.names A character vector of column names to be used in the table.
#' @param align Column alignment: a character vector consisting of \code{'l'}
#'   (left), \code{'c'} (center) and/or \code{'r'} (right). By default or if
#'   \code{align = NULL}, numeric columns are right-aligned, and other columns
#'   are left-aligned. If \code{length(align) == 1L}, the string will be
#'   expanded to a vector of individual letters, e.g. \code{'clc'} becomes
#'   \code{c('c', 'l', 'c')}, unless the output format is LaTeX.
#' @param caption The table caption.
#' @param label The table reference label. By default, the label is obtained
#'   from \code{knitr::\link{opts_current}$get('label')}.
#' @param format.args A list of arguments to be passed to \code{\link{format}()}
#'   to format table values, e.g. \code{list(big.mark = ',')}.
#' @param escape Boolean; whether to escape special characters when producing
#'   HTML or LaTeX tables.
#' @param ... Other arguments (see Examples).
#' @return A character vector of the table source code.
#' @seealso Other R packages such as \pkg{huxtable}, \pkg{xtable},
#'   \pkg{kableExtra}, and \pkg{tables} for HTML and LaTeX tables, and
#'   \pkg{ascii} and \pkg{pander} for different flavors of markdown output and
#'   some advanced features and table styles.
#' @note The tables for \code{format = 'markdown'} also work for Pandoc when the
#'   \code{pipe_tables} extension is enabled (this is the default behavior for
#'   Pandoc >= 1.10).
#'
#'   When using \code{kable()} as a \emph{top-level} expression, you do not need
#'   to explicitly \code{print()} it due to R's automatic implicit printing.
#'   When it is wrapped inside other expressions (such as a \code{\link{for}}
#'   loop), you must explicitly \code{print(kable(...))}.
#' @references See
#'   \url{https://github.com/yihui/knitr-examples/blob/master/091-knitr-table.Rnw}
#'    for some examples in LaTeX, but they also apply to other document formats.
#' @export
#' @examples  kable(head(iris), format = 'latex')
#' kable(head(iris), format = 'html')
#' kable(head(iris), format = 'latex', caption = 'Title of the table')
#' kable(head(iris), format = 'html', caption = 'Title of the table')
#' # use the booktabs package
#' kable(mtcars, format = 'latex', booktabs = TRUE)
#' # use the longtable package
#' kable(matrix(1000, ncol=5), format = 'latex', digits = 2, longtable = TRUE)
#' # change LaTeX default table environment
#' kable(head(iris), format = "latex", caption = "My table", table.envir='table*')
#' # add some table attributes
#' kable(head(iris), format = 'html', table.attr = 'id="mytable"')
#' # reST output
#' kable(head(mtcars), format = 'rst')
#' # no row names
#' kable(head(mtcars), format = 'rst', row.names = FALSE)
#' # R Markdown/Github Markdown tables
#' kable(head(mtcars[, 1:5]), format = 'markdown')
#' # no inner padding
#' kable(head(mtcars), format = 'markdown', padding = 0)
#' # more padding
#' kable(head(mtcars), format = 'markdown', padding = 2)
#' # Pandoc tables
#' kable(head(mtcars), format = 'pandoc', caption = 'Title of the table')
#' # format numbers using , as decimal point, and ' as thousands separator
#' x = as.data.frame(matrix(rnorm(60, 1e6, 1e4), 10))
#' kable(x, format.args = list(decimal.mark = ',', big.mark = "'"))
#' # save the value
#' x = kable(mtcars, format = 'html')
#' cat(x, sep = '\n')
#' # can also set options(knitr.table.format = 'html') so that the output is HTML
kable = function(
  x, format, digits = getOption('digits'), row.names = NA, col.names = NA,
  align, caption = NULL, label = NULL, format.args = list(), escape = TRUE, ...
) {

  # determine the table format
  if (missing(format) || is.null(format)) format = getOption('knitr.table.format')
  if (is.null(format)) format = if (is.null(pandoc_to())) switch(
    out_format() %n% 'markdown',
    latex = 'latex', listings = 'latex', sweave = 'latex',
    html = 'html', markdown = 'markdown', rst = 'rst',
    stop('table format not implemented yet!')
  ) else if (isTRUE(opts_knit$get('kable.force.latex')) && is_latex_output()) {
    # force LaTeX table because Pandoc's longtable may not work well with floats
    # http://tex.stackexchange.com/q/276699/9128
    'latex'
  } else 'pandoc'
  if (is.function(format)) format = format()

  # expand align if applicable
  if (format != 'latex' && !missing(align) && length(align) == 1L)
    align = strsplit(align, '')[[1]]

  # create a label for bookdown if applicable
  if (is.null(label)) label = opts_current$get('label')
  if (!is.null(caption) && !is.na(caption)) caption = paste0(
    create_label('tab:', label, latex = (format == 'latex')), caption
  )
  if (inherits(x, 'list')) {
    # if the output is for Pandoc and we want multiple tabular in one table, we
    # should use the latex format instead, because Pandoc does not support
    # Markdown in LaTeX yet https://github.com/jgm/pandoc/issues/2453
    if (format == 'pandoc' && is_latex_output()) format = 'latex'
    res = lapply(
      x, kable, format = format, digits = digits, row.names = row.names,
      col.names = col.names, align = align, caption = NA,
      format.args = format.args, escape = escape, ...
    )
    res = unlist(lapply(res, paste, collapse = '\n'))
    res = if (format == 'latex') {
      kable_latex_caption(res, caption)
    } else if (format == 'html' || (format == 'pandoc' && is_html_output())) kable_html(
      matrix(paste0('\n\n', res, '\n\n'), 1), caption = caption, escape = FALSE,
      table.attr = 'class="kable_wrapper"'
    ) else {
      res = paste(res, collapse = '\n\n')
      if (format == 'pandoc') kable_pandoc_caption(res, caption) else res
    }
    return(structure(res, format = format, class = 'knitr_kable'))
  }
  if (!is.matrix(x)) x = as.data.frame(x)
  if (identical(col.names, NA)) col.names = colnames(x)
  m = ncol(x)
  # numeric columns
  isn = if (is.matrix(x)) rep(is.numeric(x), m) else sapply(x, is.numeric)
  if (missing(align) || (format == 'latex' && is.null(align)))
    align = ifelse(isn, 'r', 'l')
  # rounding
  digits = rep(digits, length.out = m)
  for (j in seq_len(m)) {
    if (is_numeric(x[, j])) x[, j] = round(x[, j], digits[j])
  }
  if (any(isn)) {
    if (is.matrix(x)) {
      if (is.table(x) && length(dim(x)) == 2) class(x) = 'matrix'
      x = format_matrix(x, format.args)
    } else x[, isn] = format_args(x[, isn], format.args)
  }
  if (is.na(row.names)) row.names = has_rownames(x)
  if (!is.null(align)) align = rep(align, length.out = m)
  if (row.names) {
    x = cbind(' ' = rownames(x), x)
    if (!is.null(col.names)) col.names = c(' ', col.names)
    if (!is.null(align)) align = c('l', align)  # left align row names
  }
  n = nrow(x)
  x = replace_na(to_character(as.matrix(x)), is.na(x))
  if (!is.matrix(x)) x = matrix(x, nrow = n)
  x = trimws(x)
  colnames(x) = col.names
  if (format != 'latex' && length(align) && !all(align %in% c('l', 'r', 'c')))
    stop("'align' must be a character vector of possible values 'l', 'r', and 'c'")
  attr(x, 'align') = align
  res = do.call(
    paste('kable', format, sep = '_'),
    list(x = x, caption = caption, escape = escape, ...)
  )
  structure(res, format = format, class = 'knitr_kable')
}

# convert to character while preserving dim/dimnames attributes
to_character = function(x) {
  if (is.character(x)) return(x)
  x2 = as.character(x); dim(x2) = dim(x); dimnames(x2) = dimnames(x)
  x2
}

# as.data.frame() does not allow duplicate row names (#898)
format_matrix = function(x, args) {
  nms = rownames(x)
  rownames(x) = NULL
  x = as.matrix(format_args(as.data.frame(x), args))
  rownames(x) = nms
  x
}

format_args = function(x, args = list()) {
  args$x = x
  args$trim = TRUE
  replace_na(do.call(format, args), is.na(x))
}

replace_na = function(x, which = is.na(x), to = getOption('knitr.kable.NA')) {
  if (is.null(to)) return(x)
  x[which] = to
  x
}

has_rownames = function(x) {
  !is.null(rownames(x)) && !identical(rownames(x), as.character(seq_len(NROW(x))))
}

#' @export
print.knitr_kable = function(x, ...) {
  if (!(attr(x, 'format') %in% c('html', 'latex'))) cat('\n\n')
  cat(x, sep = '\n')
}

#' @export
knit_print.knitr_kable = function(x, ...) {
  x = paste(c(
    if (!(attr(x, 'format') %in% c('html', 'latex'))) c('', ''), x, '\n'
  ), collapse = '\n')
  asis_output(x)
}

kable_latex = function(
  x, booktabs = FALSE, longtable = FALSE, valign = 't', centering = TRUE,
  vline = getOption('knitr.table.vline', if (booktabs) '' else '|'),
  toprule = getOption('knitr.table.toprule', if (booktabs) '\\toprule' else '\\hline'),
  bottomrule = getOption('knitr.table.bottomrule', if (booktabs) '\\bottomrule' else '\\hline'),
  midrule = getOption('knitr.table.midrule', if (booktabs) '\\midrule' else '\\hline'),
  linesep = if (booktabs) c('', '', '', '', '\\addlinespace') else '\\hline',
  caption = NULL, caption.short = '', table.envir = if (!is.null(caption)) 'table',
  escape = TRUE
) {
  if (!is.null(align <- attr(x, 'align'))) {
    align = paste(align, collapse = vline)
    align = paste0('{', align, '}')
  }
  centering = if (centering && !is.null(caption)) '\n\\centering'
  # vertical align only if 'caption' is not NULL (may be NA) or 'valign' has
  # been explicitly specified
  valign = if ((!is.null(caption) || !missing(valign)) && valign != '') {
    sprintf('[%s]', valign)
  } else ''
  if (identical(caption, NA)) caption = NULL
  env1 = sprintf('\\begin{%s}%s\n', table.envir, valign)
  env2 = sprintf('\n\\end{%s}',   table.envir)
  if (caption.short != '') caption.short = paste0('[', caption.short, ']')
  cap = if (is.null(caption)) '' else sprintf('\n\\caption%s{%s}', caption.short, caption)

  if (nrow(x) == 0) midrule = ""

  linesep = if (nrow(x) > 1) {
    c(rep(linesep, length.out = nrow(x) - 1), '')
  } else rep('', nrow(x))
  linesep = ifelse(linesep == "", linesep, paste0('\n', linesep))

  if (escape) x = escape_latex(x)
  if (!is.character(toprule)) toprule = NULL
  if (!is.character(bottomrule)) bottomrule = NULL
  tabular = if (longtable) 'longtable' else 'tabular'

  paste(c(
    if (!longtable) c(env1, cap, centering),
    sprintf('\n\\begin{%s}', tabular), align,
    if (longtable && cap != '') c(cap, '\\\\'),
    sprintf('\n%s', toprule), '\n',
    if (!is.null(cn <- colnames(x))) {
      if (escape) cn = escape_latex(cn)
      paste0(paste(cn, collapse = ' & '), sprintf('\\\\\n%s\n', midrule))
    },
    paste0(apply(x, 1, paste, collapse = ' & '), sprintf('\\\\%s', linesep),
           collapse = '\n'),
    sprintf('\n%s', bottomrule),
    sprintf('\n\\end{%s}', tabular),
    if (!longtable) env2
  ), collapse = '')
}

kable_latex_caption = function(x, caption) {
  paste(c(
    '\\begin{table}\n', sprintf('\\caption{%s}\n', caption), x, '\n\\end{table}'
  ), collapse = '')
}

kable_html = function(x, table.attr = '', caption = NULL, escape = TRUE, ...) {
  table.attr = trimws(table.attr)
  # need a space between <table and attributes
  if (nzchar(table.attr)) table.attr = paste('', table.attr)
  align = if (is.null(align <- attr(x, 'align'))) '' else {
    sprintf(' style="text-align:%s;"', c(l = 'left', c = 'center', r = 'right')[align])
  }
  if (identical(caption, NA)) caption = NULL
  cap = if (length(caption)) sprintf('\n<caption>%s</caption>', caption) else ''
  if (escape) x = escape_html(x)
  paste0(c(
    sprintf('<table%s>%s', table.attr, cap),
    if (!is.null(cn <- colnames(x))) {
      if (escape) cn = escape_html(cn)
      c(' <thead>', '  <tr>', sprintf('   <th%s> %s </th>', align, cn), '  </tr>', ' </thead>')
    },
    '<tbody>',
    paste(
      '  <tr>',
      apply(x, 1, function(z) paste(sprintf('   <td%s> %s </td>', align, z), collapse = '\n')),
      '  </tr>', sep = '\n'
    ),
    '</tbody>',
    '</table>'
  ), collapse = '\n')
}

#' Generate tables for Markdown and reST
#'
#' This function provides the basis for Markdown and reST tables.
#' @param x The data matrix.
#' @param sep.row A length-3 character vector, specifying separators to be printed
#'   before the header, after the header, and at the end of the table respectively.
#' @param sep.col The column separator.
#' @param padding Number of spaces for the table cell padding.
#' @param align.fun A function to process the separator under the header
#'   according to the alignment.
#' @return A character vector of the table content.
#' @noRd
kable_mark = function(x, sep.row = c('=', '=', '='), sep.col = '  ', padding = 0,
                      align.fun = function(s, a) s, rownames.name = '', ...) {
  # when the column separator is |, replace existing | with its HTML entity
  if (sep.col == '|') for (j in seq_len(ncol(x))) {
    x[, j] = gsub('\\|', '&#124;', x[, j])
  }
  l = if (prod(dim(x)) > 0) apply(x, 2, function(z) max(nchar(z, type = 'width'), na.rm = TRUE))
  cn = colnames(x)
  if (length(cn) > 0) {
    cn[is.na(cn)] = "NA"
    if (sep.col == '|') cn = gsub('\\|', '&#124;', cn)
    if (grepl('^\\s*$', cn[1L])) cn[1L] = rownames.name  # no empty cells for reST
    l = pmax(if (length(l) == 0) 0 else l, nchar(cn, type = 'width'))
  }
  align = attr(x, 'align')
  padding = padding * if (length(align) == 0) 2 else {
    ifelse(align == 'c', 2, 1)
  }
  l = pmax(l + padding, 3)  # at least of width 3 for Github Markdown
  s = unlist(lapply(l, function(i) paste(rep(sep.row[2], i), collapse = '')))
  res = rbind(if (!is.na(sep.row[1])) s, cn, align.fun(s, align),
              x, if (!is.na(sep.row[3])) s)
  apply(mat_pad(res, l, align), 1, paste, collapse = sep.col)
}

kable_rst = function(x, rownames.name = '\\', ...) {
  kable_mark(x, rownames.name = rownames.name)
}

# actually R Markdown
kable_markdown = function(x, padding = 1, ...) {
  if (is.null(colnames(x))) {
    warning('The table should have a header (column names)')
    colnames(x) = rep('', ncol(x))
  }
  res = kable_mark(x, c(NA, '-', NA), '|', padding, align.fun = function(s, a) {
    if (is.null(a)) return(s)
    r = c(l = '^.', c = '^.|.$', r = '.$')
    for (i in seq_along(s)) {
      s[i] = gsub(r[a[i]], ':', s[i])
    }
    s
  }, ...)
  sprintf('|%s|', res)
}

kable_pandoc = function(x, caption = NULL, padding = 1, ...) {
  # pandoc's table format cannot create 1-column or 0-row tables
  tab = if (ncol(x) == 1 || nrow(x) == 0) kable_markdown(
    x, padding = padding, ...
  ) else kable_mark(
    x, c(NA, '-', if (is_blank(colnames(x))) '-' else NA),
    padding = padding, ...
  )
  kable_pandoc_caption(tab, caption)
}

kable_pandoc_caption = function(x, caption) {
  if (identical(caption, NA)) caption = NULL
  if (length(caption)) c(paste('Table:', caption), "", x) else x
}

# pad a matrix
mat_pad = function(m, width, align = NULL) {
  n = nrow(m); p = ncol(m)
  res = matrix('', nrow = n, ncol = p)
  if (n * p == 0) return(res)
  stopifnot(p == length(width))
  side = rep('both', p)
  if (!is.null(align)) side = c(l = 'right', c = 'both', r = 'left')[align]
  apply(m, 2, function(x) max(nchar(x, 'width') - nchar(x, 'chars')))
  matrix(pad_width(c(m), rep(width, each = n), rep(side, each = n)), ncol = p)
}

# pad a character vector to width (instead of number of chars), considering the
# case of width > chars (e.g. CJK chars)
pad_width = function(x, width, side) {
  if (!all(side %in% c('left', 'right', 'both')))
    stop("'side' must be 'left', 'right', or 'both'")
  w = width - nchar(x, 'width')
  w1 = floor(w / 2)  # the left half of spaces when side = 'both'
  s1 = v_spaces(w * (side == 'left') + w1 * (side == 'both'))
  s2 = v_spaces(w * (side == 'right') + (w - w1) * (side == 'both'))
  paste0(s1, x, s2)
}

# vectorized over n to generate sequences of spaces
v_spaces = function(n) {
  unlist(lapply(n, highr:::spaces))
}
