define -> [
		regexToMatch: /Too many }'s/
		humanReadableMessage: """
			<p>The reason LaTeX thinks there are too many }'s here is that the opening curly brace is missing after the <tt>\date</tt> control sequence and before the word December, so the closing curly brace is seen as one too many (which it is!). In fact, there are other things which can follow the <tt>\date</tt> command apart from a date in curly braces, so LaTeX cannot possibly guess that you've missed out the opening curly brace until it finds a closing one!</p>
		"""
	,
		regexToMatch: /Undefined control sequence/
		humanReadableMessage: """
			<p>In this example, LaTeX is complaining that it has no such command ("control sequence") as <tt>\dtae</tt>. Obviously it's been mistyped, but only a human can detect that fact: all LaTeX knows is that <tt>\dtae</tt> is not a command it knows about: it's undefined. Mistypings are the most common source of errors. Some editors allow common commands and environments to be inserted using drop-down menus or icons, which may be used to avoid these errors.</p>
		"""
	,
		regexToMatch: /Missing \$ inserted/
		humanReadableMessage: """
			<p>A character that can only be used in the mathematics was inserted in normal text. If you intended to use mathematics mode, then use <tt>$...$</tt> or <tt>\begin{math}...\end{math}</tt> or use the 'quick math mode': <tt>\ensuremath{...}</tt>. If you did not intend to use mathematics mode, then perhaps you are trying to use a <a href="/wiki/LaTeX/Basics#Special_Characters" title="LaTeX/Basics">special character</a> that needs to be entered in a different way; for example <tt>_</tt> will be interpreted as a subscript operator in mathematics mode, and you need <tt>\_</tt> to get an underscore character.</p>
			<p>This can also happen if you use the wrong character encoding, for example using utf8 without "\\usepackage[utf8]{inputenc}" or using iso8859-1 without "\\usepackage[latin1]{inputenc}", there are several character encoding formats, make sure to pick the right one.</p>
		"""
	,
		regexToMatch: /Runaway argument/
		humanReadableMessage: """
			<p>In this error, the closing curly brace has been omitted from the date. It's the opposite of the error of too many }'s, and it results in <tt>\maketitle</tt> trying to format the title page while LaTeX is still expecting more text for the date! As \maketitle creates new paragraphs on the title page, this is detected and LaTeX complains that the previous paragraph has ended but \date is not yet finished.</p>
		"""
	,
		regexToMatch: /Underfull \\hbox/
		humanReadableMessage: """
			<p>This is a warning that LaTeX cannot stretch the line wide enough to fit, without making the spacing bigger than its currently permitted maximum. The badness (0-10,000) indicates how severe this is (here you can probably ignore a badness of 1394). It says what lines of your file it was typesetting when it found this, and the number in square brackets is the number of the page onto which the offending line was printed. The codes separated by slashes are the typeface and font style and size used in the line. Ignore them for the moment.</p>
			<p>This comes up if you force a linebreak, e.g., \\, and have a return before it. Normally TeX ignores linebreaks, providing full paragraphs to ragged text. In this case it is necessary to pull the linebreak up one line to the end of the previous sentence.</p>
			<p>This warning may also appear when inserting images. It can be avoided by using the \textwidth or possibly \linewidth options, e.g. \includegraphics[width=\textwidth]{image_name}</p>
		"""
	,
		regexToMatch: /Overfull \\hbox/
		humanReadableMessage: """
			<p>An overfull \hbox means that there is a hyphenation or justification problem: moving the last word on the line to the next line would make the spaces in the line wider than the current limit; keeping the word on the line would make the spaces smaller than the current limit, so the word is left on the line, but with the minimum allowed space between words, and which makes the line go over the edge.</p>
			<p>The warning is given so that you can find the line in the code that originates the problem (in this case: 860-861) and fix it. The line on this example is too long by a shade over 9pt. The chosen hyphenation point which minimizes the error is shown at the end of the line (Win-). Line numbers and page numbers are given as before. In this case, 9pt is too much to ignore (over 3mm), and a manual correction needs making (such as a change to the hyphenation), or the flexibility settings need changing.</p>
			<p>If the "overfull" word includes a forward slash, such as "<code>input/output</code>", this should be properly typeset as "<code>input\slash output</code>". The use of <code>\slash</code> has the same effect as using the "<code>/</code>" character, except that it can form the end of a line (with the following words appearing at the start of the next line). The "<code>/</code>" character is typically used in units, such as "<code>mm/year</code>" character, which should not be broken over multiple lines.</p>
			<p>The warning can also be issued when the \end{document} tag was not included or was deleted.</p>
		"""
	,
		regexToMatch: /LaTeX Error: File .* not found/
		humanReadableMessage: """
			<p>When you use the <tt>\\usepackage</tt> command to request LaTeX to use a certain package, it will look for a file with the specified name and the filetype <tt>.sty</tt>. In this case the user has mistyped the name of the paralist package, so it's easy to fix. However, if you get the name right, but the package is not installed on your machine, you will need to download and install it before continuing. If you don't want to affect the global installation of the machine, you can simply download from Internet the necessary <tt>.sty</tt> file and put it in the same folder of the document you are compiling.</p>
		"""
]