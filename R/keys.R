#' Retrieve public keys.
#'
#' @name keys
#' @examples
#' travis_key("hadley/dplyr")
#' github_key("hadley")
#' \donttest{
#' local_key()
#' }
NULL

#' @rdname keys
#' @param repo Travis repository name (x/y)
#' @export
travis_key <- function(repo) {
  url <- paste0("https://api.travis-ci.org/repos/", repo, "/key")
  r <- httr::GET(url)
  httr::stop_for_status(r)

  parse_pubkey_string(gsub(" RSA", "", httr::content(r)$key[[1]]))
}

travis_encrypt <- function(repo, string) {
  stopifnot(is.character(string), length(string) == 1)

  key <- travis_key(repo)
  PKI::raw2hex(PKI::PKI.encrypt(charToRaw(string), key), sep = "")
}

#' @rdname keys
#' @param username Github username
#' @param i Key to use, if more than one
#' @export
github_key <- function(username, i = 1) {
  url <- paste0("https://api.github.com/users/", username, "/keys")
  r <- httr::GET(url)
  httr::stop_for_status(r)

  parse_pubkey_string(httr::content(r)[[i]]$key)
}

#' @rdname keys
#' @param name Name of key. If missing, uses first file in directory,
#'   otherwise uses first file that matches \code{name}.
#' @export
local_key <- function(name = "id_rsa") {
  public_keys <- dir("~/.ssh", pattern = "\\.(pub|pem)$", full.names = TRUE)

  if (is.null(name)) {
    key <- public_keys[[1]]
  } else {
    matches <- grepl(name, basename(public_keys), fixed = TRUE)
    if (!any(matches)) stop("No key matches ", name, call. = FALSE)

    key <- public_keys[matches][[1]]
  }

  parse_pubkey(key)
}

#' Parse public key
#'
#' @param path Path to load public key file from
#' @param type Type of public key ("ssh" or "ssl"). If omitted, will attempt
#'   to guess from contents of key.
#' @param key Key as a string
#' @keywords internal
#' @examples
#' \donttest{
#' parse_pubkey("~/.ssh/id_rsa.pub")
#' parse_pubkey("~/.ssh/id_rsa.pem")
#' }
parse_pubkey <- function(path, type = NULL) {
  parse_pubkey_string(readLines(path), type)
}

#' @export
#' @rdname parse_pubkey
parse_pubkey_string <- function(key, type = NULL) {
  if (is.null(type)) {
    if (any(grepl("PUBLIC KEY", key))) {
      type <- "ssl"
    } else if (any(grepl("ssh-rsa", key))) {
      type <- "ssh"
    } else {
      stop("Don't know how to guess the type of this key")
    }
  }

  con <- textConnection(key)
  on.exit(close(con))

  type <- match.arg(type, c("ssh", "ssl"))
  switch(type,
    ssh = PKI::PKI.load.OpenSSH.pubkey(key, format = "key"),
    ssl = PKI::PKI.load.key(con)
  )
}
