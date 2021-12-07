
# My CV created using R

The goal of datadrivencv is to ease the burden of maintaining a CV by
separating the content from the output by treating entries as data.

## Acknowledgements

This CV was created based on the
[`datadrivencv`](http://nickstrayer.me/datadrivencv/) R package.

# Motivation

I wanted to update my CV, but editing a document/slide is quite a bit of
manual work. That is especially as this can easily lead to re-formatting
the whole file. I remembered that some people were doing CVs using
Rmarkdown. On researching, I came across the
`datadrivencv`\](<http://nickstrayer.me/datadrivencv/>) package. That
seemed like a great approach as it allows me to:

-   Store the content in a file making it easy to edit.
-   Change the style using CSS.
-   Easily create HTML and PDF versions.
-   The `datadrivencv` package creates the needed files based on
    templates. After that my CV does not depend on the package.
-   Use R (I like using R).

# Using it

The five files created by `datadrivencv` are:

| File                      | Description                                                                                                                                                                                                                                                                            |
|---------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `cv.rmd`                  | An RMarkdown file with various sections filled in. Edit this to fit your personal needs.                                                                                                                                                                                               |
| `dd_cv.css`               | A custom set of CSS styles that build on the default `Pagedown` “resume” template. Again, edit these as desired.                                                                                                                                                                       |
| `render_cv.r`             | Use this script to build your CV in both PDF and HTML at the same time.                                                                                                                                                                                                                |
| `cv_printing_functions.r` | A series of functions that perform the dirty work of turning your spreadsheet data into markdown/html and making that output work for PDF printing. E.g. Replacing markdown links with superscripts and a links section, tweaking the CSS to account for chrome printing quirks, etc.. |

## Format of spreadsheets:

The data is stored in a [Google
Sheet](https://docs.google.com/spreadsheets/d/1KcTSyanKHQ1jGnwVd6AxMcb3zXLvt-2RKzsPOfmI5Cw/edit#gid=917338460)

There are four spreadsheets of “data” that are used. These take the form
of separate sub-sheets within a google sheet. The four spreadsheets that
are needed and their columns are:

### `entries`

| Column          | Description                                                                                                                                                             |
|-----------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `section`       | Where in your CV this entry belongs                                                                                                                                     |
| `title`         | Main title of the entry                                                                                                                                                 |
| `loc`           | Location the entry occured                                                                                                                                              |
| `institution`   | Primary institution affiliation for entry                                                                                                                               |
| `start`         | Start date of entry (year). Can be left blank for single point events like a manuscript.                                                                                |
| `end`           | End year of entry. Set to “current” if entry is still ongoing.                                                                                                          |
| `description_*` | Each description column is a separate bullet point for the entry. If you need more description bullet points simply add a new column with title “description\_{4,5,..}” |

### `language_skills`

| Column  | Description                     |
|---------|---------------------------------|
| `skill` | Name of language                |
| `level` | Relative numeric level of skill |

### `text_blocks`

| Column | Description                                           |
|--------|-------------------------------------------------------|
| `loc`  | Id used for finding text block                        |
| `text` | Contents of text block. Supports markdown formatting. |

### `contact info`

| Column    | Description                                                 |
|-----------|-------------------------------------------------------------|
| `loc`     | Id of contact section                                       |
| `icon`    | Icon used from font-awesome 4 to label this contact section |
| `contact` | The actual value written for the contact entry              |

# Rendering your CV

Now that you have the templates setup and you’ve configured your data,
the last thing to do is render. The easiest way to do this is by opening
`cv.rmd` in RStudio and clicking the “Knit” button. This will render an
HTML version of your CV. However, you most likely want a PDF version of
your CV to go along with an HTML version. The easiest way to do this is
to run the included script `render_cv.r`:

### `render_cv.r`

This script will render your CV in HTML and output it as `cv.html`, it
will also turn on the `pdf_mode` parameter in `cv.rmd`, which will strip
the links out and place them at the end linked by inline superscripts.
Once the pdf version is rendered to HTML, it will then turn that HTML
into a PDF using `pagedown::chrome_print()`. By using this script you
can easily make sure your get both versions rendered at the same time
without having to manually go in and toggle the pdf mode parameter in
the yaml header and then use the print dialog in your browser.
