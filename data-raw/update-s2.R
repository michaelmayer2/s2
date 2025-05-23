
library(tidyverse)

# download S2
source_url <- "https://github.com/google/s2geometry/archive/v0.11.1.zip"
curl::curl_download(source_url, "data-raw/s2-source.tar.gz")
unzip("data-raw/s2-source.tar.gz", exdir = "data-raw")

# make sure the dir exists
s2_dir <- list.files("data-raw", "^s2geometry-[0-9.]+", include.dirs = TRUE, full.names = TRUE)
stopifnot(dir.exists(s2_dir), length(s2_dir) == 1)
src_dir <- file.path(s2_dir, "src/s2")

# Process headers
headers <- tibble(
  path = list.files(file.path(s2_dir, "src", "s2"), "\\.(h|inc)$", full.names = TRUE, recursive = TRUE),
  final_path = str_replace(path, ".*?s2/", "src/s2/")
)

# Process compilation units
source_files <- tibble(
  path = list.files(file.path(s2_dir, "src", "s2"), "\\.cc$", full.names = TRUE, recursive = TRUE),
  final_path = str_replace(path, ".*?src/", "src/") %>%
    str_replace("^.*?s2/", "src/s2/")
) %>%
  filter(!str_detect(path, "_test\\."))

# clean current headers and source files
unlink("src/s2", recursive = TRUE)

# create destination dirs
dest_dirs <- c(
  headers %>% pull(final_path),
  source_files %>% pull(final_path)
) %>%
  dirname() %>%
  unique() %>%
  sort()
dest_dirs[!dir.exists(dest_dirs)] %>% walk(dir.create, recursive = TRUE)

# copy source files
stopifnot(
  file.copy(headers$path, headers$final_path),
  file.copy(source_files$path, source_files$final_path)
)

# need to update objects
objects <- list.files("src", pattern = "\\.(cpp|cc)$", recursive = TRUE, full.names = TRUE) %>%
  gsub("\\.(cpp|cc)$", ".o", .) %>%
  gsub("src/", "", .) %>%
  paste("    ", ., "\\", collapse = "\n")

# reminders about manual modifications that are needed
# for build to succeed
print_next <- function() {
  cli::cat_rule("Manual modifications")
  cli::cat_bullet(
    "inst/include/s2/base/logging.h: ",
    "Added a 'getter' for `S2LogMessage::_severity` (silences -Wunused_member)"
  )
  cli::cat_bullet(
    "inst/include/s2/third_party/absl/base/dynamic_annotations.h: ",
    "Remove pragma suppressing diagnostics"
  )
  cli::cat_bullet(
    "inst/include/s2/base/port.h: ",
    "Add `|| defined(_WIN32)` to `#if defined(__ANDROID__) || defined(__ASYLO__)` (2 lines)"
  )
  cli::cat_bullet(
    "inst/include/s2/util/coding/coder.h[454]: ",
    "Replace call to memset() with loop over pointers ->reset() method"
  )
  cli::cat_bullet("Replace the ABSL_DEPRECATED macro with a blank macro")
  cli::cat_bullet(
    "Fix __int128 warnings under -Wpedantic by inserting __extension__ at the beginning ",
    "of expressions containing the __int128 type ",
    "(see https://github.com/abseil/abseil-cpp/issues/157 for why Google doesn't support -Wpedantic)"
  )
  cli::cat_bullet(
    "Fix zero-length array warnings under -Wpedantic by inserting __extension__ at the beginning ",
    "of expressions declaring them (s2region_coverer.h#271)"
  )
  cli::cat_bullet(
    "Fix compact_array zero-length array warning by disabling inline elements on gcc ",
    "(util/gtl/compact_array.h#89)"
  )
  cli::cat_bullet(
    "Fix sanitizer error for compact_array when increasing the size of a zero-length array ",
    "by wrapping util/gtl/compact_array.h#396-397 with if (old_capacity > 0) {...}"
  )

  cli::cat_bullet("Remove extra semi-colon at s2boolean_operation.h#376")
  cli::cat_bullet("Remove extra semi-colons because of FROMHOST_TYPE_MAP macro (utils/endian/endian.h#565)")
  cli::cat_bullet(
    "Check for definition of IS_LITTLE_ENDIAN and IS_BIG_ENDIAN to allow configure script ",
    "override (s2/base/port.h:273) without macro redefinition warnings (for CRAN Solaris)"
  )
  cli::cat_bullet(
    "Replace calls to log(<int literal>), sqrt(<int literal>), and ldexp(<int literal>, ...) ",
    "with an explicit doouble (e.g., sqrt(3) -> sqrt(3.0) to fix build errors on CRAN Solaris"
  )
  cli::cat_bullet(
    "Ensure the code compiles on clang with -Wnested-anon-types. ",
    "These errors can be fixed by declaring the anonymous types just above the union. ",
    "(e.g., encoded_s2point_vector.h:91)"
  )

  cli::cat_bullet(
    "Ensure that the uint64 type in include/s2/third_part/absl/base/internal/unaligned_access.h ",
    "is actually defined (e.g., by redeclaring as uint64_t). Caused failures on clang 12.2 on Mac OS M1"
  )

  cli::cat_bullet("Replace `abort()` with `cpp_compat_abort()`")
  cli::cat_bullet("Replace `cerr`/`cout` with `cpp_compat_cerr`/`cpp_compat_cout`")
  cli::cat_bullet("Replace `srandom()` with `cpp_compat_srandom()`")
  cli::cat_bullet("Replace `random()` with `cpp_compat_random()`")
  cli::cat_bullet("Update OBJECTS in Makevars.in and Makevars.win (copied to clipboard)")
  clipr::write_clip(objects)
}

print_next()
