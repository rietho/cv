# This file contains all the code needed to parse and print various sections of your CV
# from data. Feel free to tweak it as you desire!

here::i_am("cv_printing_functions.r")

# text aside: margin-top (between text and header)
# constant
txt_aside_margin_top <- "-5px"

#' Create a CV_Printer object.
#'
#' @param data_location Path of the spreadsheets holding all your data. This can be
#'   either a URL to a google sheet with multiple sheets containing the four
#'   data types or a path to a folder containing four `.csv`s with the neccesary
#'   data.
#' @param data_location_override Currently not in use. Could be used iun the
#'   future to read a second set of data that overrides the first set in places
#'   where they overlap
#' @param source_location Where is the code to build your CV hosted?
#' @param pdf_mode Is the output being rendered into a pdf? Aka do links need
#'   to be stripped?
#' @param sheet_is_publicly_readable If you're using google sheets for data,
#'   is the sheet publicly available? (Makes authorization easier.)
#' @return A new `CV_Printer` object.
create_CV_object <-  function(data_location,
                              data_location_override = NULL,
                              pdf_mode = FALSE,
                              sheet_is_publicly_readable = TRUE) {

  cv <- list(
    pdf_mode = pdf_mode,
    links = c()
  )

  read_data <- function(data_location) {
    is_google_sheets_location <- stringr::str_detect(data_location, "docs\\.google\\.com")

    if(is_google_sheets_location){
      if(sheet_is_publicly_readable){
        # This tells google sheets to not try and authenticate. Note that this will only
        # work if your sheet has sharing set to "anyone with link can view"
        googlesheets4::gs4_deauth()
      } else {
        # if you want to use a private sheet, then this is the way you need to do it.
        # designate project-specific cache so we can render Rmd without problems
        # code to generate .secrets:
        # # designate project-specific cache
        # options(gargle_oauth_cache = “.secrets”)
        # # check the value of the option, if you like
        # gargle::gargle_oauth_cache()
        # # trigger auth on purpose to store a token in the specified cache a
        # # browser will be opened
        # googlesheets4::sheets_auth()
        options(gargle_oauth_cache = ".secrets")
      }

      read_gsheet <- function(data_location, sheet_id){
        googlesheets4::read_sheet(ss = data_location, sheet = sheet_id, skip = 1, col_types = "c")
      }
      cv$entries_data  <- read_gsheet(data_location, sheet_id = "entries")
      cv$skills        <- read_gsheet(data_location, sheet_id = "skills")
      cv$text_blocks   <- read_gsheet(data_location, sheet_id = "text_blocks")
      cv$contact_info  <- read_gsheet(data_location, sheet_id = "contact_info")
      cv$settings      <- read_gsheet(data_location, sheet_id = "settings")
    } else {
      # Want to go old-school with csvs?
      cv$entries_data <- readr::read_csv(paste0(data_location, "entries.csv"), skip = 1)
      cv$skills       <- readr::read_csv(paste0(data_location, "skills.csv"), skip = 1)
      cv$text_blocks  <- readr::read_csv(paste0(data_location, "text_blocks.csv"), skip = 1)
      cv$contact_info <- readr::read_csv(paste0(data_location, "contact_info.csv"), skip = 1)
      cv$settings <- readr::read_csv(paste0(data_location, "settings.csv"), skip = 1)
    }
    return(cv)
  }
  cv <- read_data(data_location)

  extract_year <- function(dates){
    date_year <- stringr::str_extract(dates, "(20|19)[0-9]{2}")
    date_year[is.na(date_year)] <- lubridate::year(lubridate::ymd(Sys.Date())) + 10

    date_year
  }

  parse_dates <- function(dates){

    # expecting mm-yyyy format ("-" could also be " " or "/)
    date_month <- stringr::str_extract(dates, r"{(\w+|\d+)(?=(\s|\/|-)(20|19)[0-9]{2})}")
    # where no month found:
    # expecting yyyy-mm format ("-" could also be " " or "/)
    date_month[is.na(date_month)] <-
      stringr::str_extract(date_month[is.na(date_month)], r"{(?<=(20|19)[0-9]{2}(\s|\/|-))(\w+|\d+)}")
    date_month[is.na(date_month)] <- "1"

    paste("1", date_month, extract_year(dates), sep = "-") %>%
      lubridate::dmy()
  }

  # Clean up entries dataframe to format we need it for printing
  cv$entries_data %<>%
    dplyr::mutate(dplyr::across(
      dplyr::starts_with("description"),
      ~ dplyr::if_else(stringr::str_starts(.x, "<exclude>"), NA_character_, .x)
    )) %>%
    tidyr::unite(
      tidyr::starts_with('description'),
      col = "description_bullets",
      sep = "\n",
      na.rm = TRUE
    ) %>%
    dplyr::mutate(
      start = ifelse(start == "NULL", NA, start),
      end = ifelse(end == "NULL", NA, end),
      start_year = extract_year(start),
      end_year = extract_year(end),
      no_start = is.na(start),
      has_start = !no_start,
      no_end = is.na(end),
      has_end = !no_end,
      timeline = dplyr::case_when(
        no_start  & no_end  ~ "N/A",
        no_start  & has_end ~ as.character(end),
        has_start & no_end  ~ paste(start, "-", "Current"),
        TRUE                ~ paste(start, "-", end)
      ),
      in_resume = dplyr::case_when(
        stringr::str_to_upper(in_resume) == "TRUE" ~ TRUE,
        stringr::str_to_upper(in_resume) == "FALSE" ~ FALSE,
        TRUE ~ FALSE
      )
    ) %>%
    dplyr::arrange(desc(parse_dates(end))) %>%
    dplyr::mutate_all(~ ifelse(is.na(.), 'N/A', .)) %>%
    dplyr::filter(in_resume)

  # filter skills
  cv$skills %<>%
    dplyr::mutate(
      in_resume = dplyr::case_when(
        stringr::str_to_upper(in_resume) == "TRUE" ~ TRUE,
        stringr::str_to_upper(in_resume) == "FALSE" ~ FALSE,
        TRUE ~ FALSE
      )
    ) %>%
    dplyr::filter(in_resume)

  #' @description get a settings list based on the CV object
  get_settings_list <- function(cv) {
    setNames(as.list(cv$settings$setting), cv$settings$loc)
  }
  cv$settings <- get_settings_list(cv)

  cv
}


# Remove links from a text block and add to internal list
sanitize_links <- function(cv, text){
  if(cv$pdf_mode){
    link_titles <- stringr::str_extract_all(text, '(?<=\\[).+?(?=\\]\\()')[[1]]
    link_destinations <- stringr::str_extract_all(text, '(?<=\\]\\().+?(?=\\))')[[1]]

    n_links <- length(cv$links)
    n_new_links <- length(link_titles)

    if(n_new_links > 0){
      # add links to links array
      cv$links <- c(cv$links, link_destinations)

      # Build map of link destination to superscript
      link_superscript_mappings <- purrr::set_names(
        paste0("<sup>", (1:n_new_links) + n_links, "</sup>"),
        paste0("(", link_destinations, ")")
      )

      # Replace the link destination and remove square brackets for title
      text <- text %>%
        stringr::str_replace_all(stringr::fixed(link_superscript_mappings)) %>%
        stringr::str_replace_all('\\[(.+?)\\]', "\\1")
    }
  }

  list(cv = cv, text = text)
}


#' @description Take a position data frame and the section id desired and prints the section to markdown.
#' @param section_id ID of the entries section to be printed as encoded by the `section` column of the `entries` table
#'
#' Description could be made concise (i.e. 2 columns) via:
#' :::concise
#' {description_bullets}
#' :::
print_section <- function(cv, section_id, glue_template = "default"){

  if(glue_template == "default"){
    glue_template <- "
### {title}

{institution}

{loc}

{timeline}

{description_bullets}
\n\n\n"
  }

  section_data <- dplyr::filter(cv$entries_data, section == section_id)

  # Take entire entries data frame and removes the links in descending order
  # so links for the same position are right next to each other in number.
  # for(i in 1:nrow(section_data)){
  #   for(col in c('title', 'description_bullets')){
  #     strip_res <- sanitize_links(cv, section_data[i, col])
  #     section_data[i, col] <- strip_res$text
  #     cv <- strip_res$cv
  #   }
  # }

  print(glue::glue_data(section_data, glue_template))

  invisible(cv) #invisible(strip_res$cv)
}

#' @description Prints text if certain type like headers
#'
#' @param cv CV object
#' @param id string specifying the ID per the data entry (column `loc`)
#' @param type string specyfing the type of text
#' @param post_text some text that comes post the other text
print_text <- function(cv, id, type = c("plain", "subtitle", "title"), post_text = "") {
  type <- match.arg(type, c("subtitle", "title", "plain"))

  pre_text <- switch(
    type,
    subtitle = "### ",
    title = "## ",
    plain = "")

  text <- dplyr::filter(cv$text_blocks, loc == id) %>%
    dplyr::pull(text)

  if (length(text) > 0) {
    cat(paste0(pre_text, text, post_text))
  }

  invisible(cv)
}


#' @description Prints out text html code for linking to pdf/html version of the CV
#' @param mode mode of the CV, either html or pdf
print_online_version_text <- function(cv, mode = c("html", "pdf")) {
  mode <- match.arg(mode, c("html", "pdf"))

  # get text blocks
  link <- cv$text_block |>
    dplyr::filter(loc == glue::glue("{mode}_link")) |>
    dplyr::pull(text)
  link_text <- cv$text_block |>
    dplyr::filter(loc == glue::glue("{mode}_link_text")) |>
    dplyr::pull(text)
  text <- cv$text_block |> dplyr::filter(loc == "html_link") |> dplyr::pull(text)

  online_version_text <- glue::glue(
    r"[[{{link_text}}]({{link}}){target="_blank"}]",
    .open = "{{",
    .close = "}}",
    )

  print(online_version_text)

  invisible(cv)
}


#' @description Prints out HTML to insert image
print_image_html <- function(cv) {
  settings <- cv$settings

  image_html <- glue::glue(r"[<center>
<!--[![logo](frame.svg){width=75%, target="_blank"}](https://www.linkedin.com/in/thomas-lieb-158576a0/)-->
[![logo]({{settings$image_path}}){width=75%}]({{settings$image_url}}){target="_blank"}
</center>]", .open = "{{", .close = "}}")

  image_html <- image_html |>
    stringr::str_replace(r"[\[(\!\[[^\]]*\].*)\]\(NA\)\{target=\"_blank\"\}]", "\\1")

  print(glue::as_glue(image_html))
  invisible(cv)
}


#' @description Construct a bar chart of skills
#' @param out_of The relative maximum for skills. Used to set what a fully filled in skill bar is.
print_skill_bars <- function(cv, out_of = 5, bar_color = "#969696", bar_background = "#d9d9d9", glue_template = "default", category_filter = "technical"){

  if(glue_template == "default"){
    glue_template <- "
<div
  class = 'skill-bar'
  style = \"background:linear-gradient(to right,
                                      {bar_color} {width_percent}%,
                                      {bar_background} {width_percent}% 100%)\"
>{skill}</div>"
  }
  cv$skills %>%
    dplyr::filter(category == category_filter) %>%
    dplyr::arrange(order) %>%
    dplyr::mutate(width_percent = round(100*as.numeric(level_num)/out_of)) %>%
    glue::glue_data(glue_template) %>%
    print()

  invisible(cv)
}


#' @description Construct table of language skills
print_languages_table <- function(cv, glue_template = "default", category_filter = "language"){

  if(glue_template == "default"){
    glue_template_pre <- "<table class='skill_table'>
"
    glue_template <- "
<tr>
    <td style='padding-right:7px;'>{skill}</td>
    <td style='padding-left:7px;'>{level_cat}</td>
</tr>"
    glue_template_post <- "
</table>"
  } else {
    glue_template_pre <- glue_template_post <- ""
  }
  table_txt <- cv$skills %>%
    dplyr::filter(category == category_filter) %>%
    dplyr::arrange(order) %>%
    glue::glue_data(glue_template)
  print(glue::glue(glue_template_pre, paste0(table_txt, collapse = "\n"), glue_template_post))

  invisible(cv)
}

#' @description Construct a text of skills
print_skills_text <- function(
    cv, glue_template = "default", category_filter = "other_tech",
    collapse = ", "){

  if (glue_template == "default") {
    glue_template_pre <- glue::glue("<p style='margin-top: {txt_aside_margin_top};'>")
    glue_template <- "{skill}"
    glue_template_post <- "</p>"
  } else if (glue_template == "list") {
    glue_template_pre <- glue::glue("<p style='margin-top: {txt_aside_margin_top};'>")
    glue_template <- "- {skill}"
    glue_template_post <- "</p>"
  } else {
    glue_template_pre <- glue_template_post <- ""
  }
  table_txt <- cv$skills %>%
    dplyr::filter(category == category_filter) %>%
    dplyr::arrange(order) %>%
    glue::glue_data(glue_template) %>%
    glue::glue_collapse(collapse)
  print(glue::glue(glue_template_pre, table_txt, glue_template_post))

  invisible(cv)
}


#' @description List of all links in document labeled by their superscript integer.
print_links <- function(cv) {
  n_links <- length(cv$links)
  if (n_links > 0) {
    cat("
Links {data-icon=link}
--------------------------------------------------------------------------------

<br>


")

    purrr::walk2(cv$links, 1:n_links, function(link, index) {
      print(glue::glue('{index}. {link}'))
    })
  }

  invisible(cv)
}



#' @description Contact information section with icons
print_contact_info <- function(cv){
  txt <- glue::glue_data(
    cv$contact_info,
    r"[<i class='fa fa-{icon} fa-fw'></i> <a href="{link}" target="_blank">{contact}</a> {text_add}<br>]"
  ) %>%
    # remove empty links (md version)
    stringr::str_replace("\\[(.*)\\]\\(NA\\)", "\\1") %>%
    # remove empty links (html version)
    stringr::str_replace('<a href="NA" target="_blank">(.*)</a>', "\\1") %>%
    # remove empty additional text
    stringr::str_replace('(.*) NA', "\\1") %>%
    glue::as_glue()
  print(glue::glue(
    '<p style="line-height:1.6;margin-top: 5px">',
    paste0(txt, collapse = "\n"),
    '</p>'
    ))

  invisible(cv)
}
