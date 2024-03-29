
tidycensus_call <- function(.fn, ...) {
  args <- rlang::dots_list(..., .homonyms = "error")
  if (!rlang::is_named(args)) {
    stop("\nArguments passed to ... must all be named", call. = FALSE)
  }
  rlang::call2(.fn = .fn, !!!args, .ns = "tidycensus")
}

#' @importFrom rlang .data
get_tidycensus <- function(geography,
                           state,
                           county,
                           geoid,
                           zcta,
                           year,
                           dataset,
                           partial_tidycensus_calls,
                           geometry) {
  
  eval_insistently <- 
    purrr::insistently(eval, rate = purrr::rate_delay(), quiet = FALSE)
  
  # There are different location validation schemes for the three different user
  # input options concerning geography:
  
  # 1 ZCTA - use only zcta argument, leaving state, county, and geoid blank
  
  # 2 geoid - use only geoid argument, leaving state, county, and zcta blank
  
  # 3 state & county - use state and (optionally) county, leaving geoid and
  # zcta blank
  
  ref_area <-
    ref_area(
      geography = geography,
      state = state,
      county = county,
      zcta = zcta,
      geoid = geoid,
      year = year,
      dataset = dataset,
      partial_tidycensus_calls = partial_tidycensus_calls,
      eval_insistently = eval_insistently
    )
  
  tidycensus_data <-
    eval_tidycensus_calls(
      partial_tidycensus_calls = partial_tidycensus_calls,
      geography = geography,
      year = year,
      dataset = dataset,
      state_county = ref_area$state_county,
      geometry = geometry,
      eval_insistently = eval_insistently
    )
  
  # Since the call (or calls) to tidycensus functions usually gathers data on
  # more places than what the user specified, this pares the tidycensus-produced
  # data down to only include the user-specified reference area.
  if (!is.null(ref_area$geoid)) {
    tidycensus_data <-
      filter_ref_area(
        d = tidycensus_data,
        what = "GEOID",
        pattern = ref_area$geoid,
        geo_length = ref_area$geo_length
      )
  } else if (!is.null(ref_area$zcta)) {
    tidycensus_data <-
      filter_ref_area(
        d = tidycensus_data,
        what = "ZCTA",
        pattern = ref_area$zcta
      )
  }
  
  tidycensus_data
}


#' @importFrom rlang .data
eval_tidycensus_calls <- function(partial_tidycensus_calls,
                                  geography,
                                  year,
                                  dataset,
                                  state_county,
                                  geometry,
                                  eval_insistently) {
  if (geometry) {
    # Saves old tigris_use_cache value and puts it back when function exits
    old <- options(tigris_use_cache = TRUE)
    on.exit(options(old), add = TRUE)
  }
  
  # There is special handling of this combination of arguments because it
  # requires tidycensus::get_decennial() to be called once for every state in
  # the reference area and tidycensus::get_acs() to be called once for every
  # county in the reference area. All other combinations of
  # geography/year/dataset either only call one of the two tidycensus functions
  # or require the same number of calls from each of them.
  if (geography == "tract" && year == 2010 && dataset == "decennial" &&
      setequal(
        names(partial_tidycensus_calls),
        c("get_decennial", "get_acs")
      )
  ) {
    
    # state_county contains one row for each county already, so a call to
    # tidycensus::get_acs() will be created for every county in the reference
    # area.
    acs_calls <-
      purrr::pmap(
        .l = state_county,
        .f = rlang::call_modify, 
        .call = partial_tidycensus_calls$get_acs
      )
    
    # The unique states within state_county are first extracted via
    # dplyr::distinct(), and then a call to tidycensus::get_decennial() will be
    # created for each state in the reference area.
    decennial_calls <-
      state_county %>% 
      dplyr::distinct(.data$state) %>% 
      purrr::pmap(
        rlang::call_modify,
        .call = partial_tidycensus_calls$get_decennial
      )
    
    message(
      "\n",
      length(acs_calls) + length(decennial_calls),
      " call(s) to tidycensus beginning."
    )
    
    acs_data <- lapply(acs_calls, eval_insistently)
    acs_data <- do.call(rbind, acs_data)
    acs_data <- wrangle_raw_tidycensus(acs_data, partial_tidycensus_calls)
    
    decennial_data <- lapply(decennial_calls, eval_insistently)
    decennial_data <- do.call(rbind, decennial_data)
    decennial_data <-
      wrangle_raw_tidycensus(decennial_data, partial_tidycensus_calls)
    
    # Since get_decennial() calls are only broken up by state (see above), lots
    # of extra counties' data may be present. Since get_acs() is broken up by
    # county, it does not have this problem. Therefore, the results of the
    # former are filtered to only include tracts present in the results of the
    # latter.
    decennial_data <-
      dplyr::semi_join(decennial_data, as.data.frame(acs_data), by = "GEOID")
    
    d <- rbind(decennial_data, acs_data)
    
  } else {
    
    # When we don't have to worry about the headache of different numbers of
    # calls needed for get_decennial() and get_acs(), we can simply use
    # tidyr::expand_grid() to create a separate call for each combination of the
    # elements of state_county and the elements of tidycensus_calls.
    tidycensus_calls <- 
      state_county %>% 
      tidyr::expand_grid(.call = partial_tidycensus_calls) %>% 
      purrr::pmap(rlang::call_modify)
    
    message("\n", length(tidycensus_calls), " call(s) to tidycensus beginning.")
    
    d <- lapply(tidycensus_calls, eval_insistently)
    d <- lapply(d, wrangle_raw_tidycensus, partial_tidycensus_calls)
    d <- do.call(rbind, d)
    
  }
  
  # Since the contents of "d" may be the results of multiple different calls
  # to tidycensus function(s), sometimes the same geographic area (i.e., same
  # GEOID) will have inconsistent NAME or geometry values. The code below
  # essentially standardizes each GEOID's NAME and geometry, using the first
  # NAME and geometry value for each GEOID (found by match()).
  geoid_match <- d$GEOID %>% match(., .)
  d$NAME <- d$NAME[geoid_match]
  if (inherits(d, "sf")) {
    d$geometry <- d$geometry[geoid_match]
  }
  
  if (all(c("names_to_spread", "values_to_spread") %in% names(d))) {
    # tidyr::pivot_wider() didn't initially support sf-tibbles so we didn't
    # end up implementing it. tidyr::pivot_wider(result, names_from = "names",
    # values_from = "values")
    # cols_in_order <- unique(d$names_to_spread)
    d <- tidyr::spread(d, key = "names_to_spread", value = "values_to_spread")
    # d <- d[c("GEOID", "NAME", cols_in_order)]
  }
  
  d
}



wrangle_raw_tidycensus <- function(d, partial_tidycensus_calls) {
  # dplyr::select_if() pulls all non-geometry columns to the left because the
  # geometry column is not an atomic vector (it's a list). This allows us to
  # select the inconsistently named Census variable name and Census variable
  # value columns by position.
  d <- dplyr::select_if(d, is.atomic)
  
  # We then wrangle the data depending on whether the tidycensus called
  # requested "tidy" or "wide" data.
  switch(
    partial_tidycensus_calls[[1L]]$output,
    tidy = {
      d <-
        dplyr::select(
          d,
          "GEOID",
          "NAME",
          names_to_spread = 3L,
          values_to_spread = 4L
        )
    },
    wide = {
      d <- dplyr::select(d, "GEOID", "NAME", 3L)
    }
  )
    
  d
}



filter_ref_area <- function(d, what, pattern, geo_length = NULL) {
  
  # Pattern is the list of GEOIDs in the ref_area object (in the function
  # environment of get_adi()). It is called "pattern" in the sense of regular
  # expressions: each element is ultimately turned into a regular expression.
  
  # First, each element in "pattern" is truncated as needed to the number of
  # characters invoked by the "geography" argument in get_adi() (e.g., 11
  # characters if geography = "tract"). This is necessary because users are
  # permitted (with a warning) to request ADI and ADI-3 at a level of geography
  # larger than any GEOID entered into the "geoid" argument (e.g.,
  # get_adi(geography = "county", geoid = c("31415926535", "271828182845905")))
  pattern_sub <-
    if (is.null(geo_length)) {
      pattern
    } else {
      stringr::str_sub(pattern, 1L, geo_length)
    }
  
  # Second, each GEOID pattern is prepended with "^" and matched to each GEOID
  # in "d"
  matches <-
    lapply(paste0("^", pattern_sub), stringr::str_which, string = d$GEOID)
  
  # User gets a warning if any GEOID pattern did not match any of the GEOIDs in
  # the tidycensus results.
  nomatch <- lengths(matches, use.names = FALSE) == 0L
  if (any(nomatch)) {
    warning(
      "\nThe following ", what, "s had no match in census data:\n",
      paste(pattern[nomatch], collapse = ",\n")
    )
  }
  
  matches <- unique(unlist(matches, use.names = FALSE))
  # Returns any result in "d" that matched any GEOID pattern.
  d[matches, ]
}
