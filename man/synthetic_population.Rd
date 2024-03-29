% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/synthetic_population.R
\name{synthetic_population}
\alias{synthetic_population}
\title{Create a synthetic population simulating US Census areas}
\usage{
synthetic_population(
  geography,
  state = NULL,
  county = NULL,
  geoid = NULL,
  zcta = NULL,
  year,
  dataset = c("acs5", "acs3", "acs1", "decennial"),
  geometry = FALSE,
  cache_tables = TRUE,
  max_age = 115,
  rate = 0.25,
  key = NULL,
  seed = NULL,
  ...
)
}
\arguments{
\item{geography}{A character string denoting the level of US census geography
at which you want to create a synthetic population. Required.}

\item{state}{A character string specifying states whose population you want
to synthesize. Defaults to \code{NULL}. Can contain full state names, two-letter
state abbreviations, or a two-digit FIPS code/GEOID (must be a vector of
strings, so use quotation marks and leading zeros if necessary). Must be
left as \code{NULL} if using the \code{geoid} or \code{zcta} parameter.}

\item{county}{A vector of character strings specifying the counties whose
population you want to synthesize. Defaults to \code{NULL}. If not \code{NULL}, the
\code{state} parameter must have a length of 1. County names and three-digit
FIPS codes are accepted (must contain strings, so use quotation marks and
leading zeros if necessary). Must be blank if using the \code{geoid} parameter.}

\item{geoid}{A character vector of GEOIDs (use quotation marks and leading
zeros). Defaults to \code{NULL}. Must be blank if \code{state}, \code{county}, or \code{zcta}
is used. Can contain different levels of geography (see details).}

\item{zcta}{A character vector of ZCTAs or the leading digit(s) of ZCTAs (use
quotation marks and leading zeros). Defaults to \code{NULL}. Must be blank if
\code{state}, \code{county}, or \code{geoid} is used.

Strings under 5 digits long will yield all ZCTAs that begin with those
digits.

Requires that \code{geography = "zcta"}. If \code{geography = "zcta"} and \code{zcta = NULL}, all ZCTAs in the US will be used.}

\item{year, dataset}{Specifies the US Census data set on which to base the
demographic profile of your synthetic population.

\code{year} must be a single integer specifying the year of US Census data to
use.The data set used to calculate ADIs and ADI-3s.

\code{dataset} must be one of \code{c("acs5", "acs3", "acs1", "decennial")}, denoting
the 5-, 3-, and 1-year ACS along with the decennial census. Defaults to
\code{"acs5"}.

When \code{dataset = "decennial"}, \code{year} must be in \code{c(1990, 2000, 2010)}.

Important: data are not always available depending on the level of
geography and data set chosen. See
\url{https://www.census.gov/programs-surveys/acs/guidance/estimates.html}.}

\item{geometry}{Logical value indicating whether or not shapefile data should
be included in the result, making the result an \code{\link[sf:sf]{sf}} object
instead of a plain \code{\link[tibble:tibble]{tibble}}. Defaults to \code{FALSE}.

The shapefile data that is returned is somewhat customizable by passing
certain arguments along to the \code{tidycensus} functions via \code{...}.}

\item{cache_tables}{The plural version of the \code{cache_table} argument in
\code{\link[tidycensus:get_acs]{tidycensus::get_acs()}} or \code{\link[tidycensus:get_decennial]{tidycensus::get_decennial()}}. (\code{get_adi()}
calls the necessary \code{tidycensus} function many times in order to return
ADIs and ADI-3s, so many tables are cached if \code{TRUE}). Defaults to \code{TRUE}.}

\item{max_age}{A single integer representing the largest possible age that
can appear in the data set. Simulated age values exceeding this value will
be top-coded to this value. Defaults to 115. See details.}

\item{rate}{A single number, passed to \code{\link[stats:Exponential]{stats::rexp()}} when synthesizing the
ages of the highest age bracket. Defaults to 0.25. See details.}

\item{key}{Your Census API key as a character string. Obtain one at
\url{http://api.census.gov/data/key_signup.html}. Defaults to \code{NULL}. Not
necessary if you have already loaded your key with \code{\link[=census_api_key]{census_api_key()}}.}

\item{seed}{Passed onto \code{\link[=set.seed]{set.seed()}}, which is called before
probabilistically synthesizing the age values with \code{\link[=sample]{sample()}}.}

\item{...}{Additional arguments to be passed onto \code{\link[tidycensus:get_acs]{tidycensus::get_acs()}} or
\code{\link[tidycensus:get_decennial]{tidycensus::get_decennial()}}. These must all be named. Must not match any
of the \code{tidycensus} formal arguments that \code{sociome} needs to set
explicitly.

This may be found to be helpful when setting \code{geometry = TRUE}, since the
\code{tidycensus} functions pass \code{...} onto the appropriate \code{tigris} function
(namely, one of \code{\link[tigris:states]{tigris::states()}}, \code{\link[tigris:counties]{tigris::counties()}},
\code{\link[tigris:tracts]{tigris::tracts()}}, \code{\link[tigris:block_groups]{tigris::block_groups()}}, or \code{\link[tigris:zctas]{tigris::zctas()}},
according to the the value of \code{geography}). This enables the user to
somewhat customize the shapefile data obtained.}
}
\value{
If \code{geometry = FALSE}, (the default) a \code{\link[tibble:tibble]{tibble}}. If
\code{geometry = TRUE} is specified, an \code{\link[sf:sf]{sf}}.
}
\description{
Returns a data set of synthetic individuals based on user-specified US Census
areas. The age, sex, race, and ethnicity of each individual is probabilistic,
based on the demographics of the areas as reported in a user-specified US
Census data set.
}
\details{
Returns a \code{\link[tibble:tibble]{tibble}} or \code{\link[sf:sf]{sf}} object where each row
represents a synthetic person. Each person has an age, sex, race, and
ethnicity. The probability of what each person's age/sex/race/ethnicity will
be is equal to the proportions in their census area as reported in the
user-specified US Census data set (e.g., 2010 Decennial Census or 2017 ACS
5-year estimates). The number of rows in the data set will equal the number
of people living in the user-specified US Census areas, as reported in the
same US Census data set.
}
\section{Synthesizing ages from US Census Data}{
 US Census data provides
counts of the number of people in different age brackets of varying widths.
The \code{age_lo} and \code{age_hi} columns in the output depict the age bracket of
each individual in the synthetic population. There is also an \code{age} column
that probabilistically generates a non-whole-number age within the age
bracket. A uniform distribution (via \code{\link[stats:Uniform]{stats::runif()}}) guides this age
generation for all age brackets except the highest age bracket ("age 85 and
over" in the extant ACS and Decennial Census data). An exponential
distribution (via \code{\link[stats:Exponential]{stats::rexp()}}) guides the age generation for this
highest age bracket, and the user can specify \code{rate} to customize the
exponential distribution that is used.
}

\examples{
\dontrun{
# Wrapped in \dontrun{} because all these examples take >5 seconds
# and require a Census API key.

# Synthetic population for Utah, using the 2019 ACS 5-year estimates:
synthetic_population(geography = "state", state = "UT", year = 2019)

# Same, but make it so that survival past age 85 is highly unlikely
# (via rate = 10), and so that 87 is the maximum possible age
synthetic_population(
  geography = "state",
  state = "UT",
  year = 2019,
  max_age = 87,
  rate = 10
)

# Synthetic population of the Delmarva Peninsula at the census tract level,
# using 2000 Decennial Census data
synthetic_population(
  geography = "tract",
  geoid = 
    # This two-digit GEOID is the state of Delaware.
    c("10",
    
    # These five-digit GEOIDs are specific counties in Virginia and Maryland
      "51001", "51131", "24015", "24029", "24035", "24011", "24041", "24019",
      "24045", "24039", "24047"),
  year = 2000,
  dataset = "decennial"
)
}
}
