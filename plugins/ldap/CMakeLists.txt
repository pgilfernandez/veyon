include(BuildVeyonPlugin)

if(DEFINED WITH_LDAP AND NOT WITH_LDAP)
	message(STATUS "LDAP plugin disabled via WITH_LDAP=OFF")
elseif(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/kldap/CMakeLists.txt)
	add_subdirectory(kldap)
	add_subdirectory(common)

	build_veyon_plugin(ldap
		NAME Ldap
		SOURCES
		LdapPlugin.cpp
		LdapPlugin.h
		)

	target_link_libraries(ldap PRIVATE ldap-common)
else()
	message(WARNING "KLDAP sources missing – skipping LDAP plugin")
endif()
