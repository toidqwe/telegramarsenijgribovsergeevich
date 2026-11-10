if (NOT "$ENV{TDESKTOP_API_ID}" MATCHES "^[1-9][0-9]*$")
    message(FATAL_ERROR "Set a valid TDESKTOP_API_ID in the local environment.")
endif()

string(LENGTH "$ENV{TDESKTOP_API_HASH}" api_hash_length)
if (NOT api_hash_length EQUAL 32 OR NOT "$ENV{TDESKTOP_API_HASH}" MATCHES "^[0-9a-fA-F]+$")
    message(FATAL_ERROR "Set a valid TDESKTOP_API_HASH in the local environment.")
endif()

set(TDESKTOP_API_TEST OFF CACHE BOOL "Use test API credentials." FORCE)
set(TDESKTOP_API_ID "$ENV{TDESKTOP_API_ID}" CACHE STRING "Telegram API application ID." FORCE)
set(TDESKTOP_API_HASH "$ENV{TDESKTOP_API_HASH}" CACHE STRING "Telegram API application hash." FORCE)
