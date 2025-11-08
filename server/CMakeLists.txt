include(BuildVeyonApplication)

build_veyon_application(veyon-server
	NAME Server
	SOURCES
	src/ComputerControlClient.cpp
	src/ComputerControlClient.h
	src/ComputerControlServer.cpp
	src/ComputerControlServer.h
	src/main.cpp
	src/ServerAccessControlManager.cpp
	src/ServerAccessControlManager.h
	src/ServerAuthenticationManager.cpp
	src/ServerAuthenticationManager.h
	src/VeyonServerProtocol.cpp
	src/VeyonServerProtocol.h
	src/VncProxyConnection.cpp
	src/VncProxyConnectionFactory.h
	src/VncProxyConnection.h
	src/VncProxyServer.cpp
	src/VncProxyServer.h
	src/VncServer.cpp
	src/VncServer.h)

if(APPLE)
	set(_veyon_macos_helpers
		veyon-service
		veyon-worker
	)
	foreach(_helper ${_veyon_macos_helpers})
		if(TARGET ${_helper})
			add_dependencies(veyon-server ${_helper})
			add_custom_command(TARGET veyon-server POST_BUILD
				COMMAND "${CMAKE_COMMAND}" -E copy "$<TARGET_FILE:${_helper}>" "$<TARGET_FILE_DIR:veyon-server>/${_helper}"
				COMMAND /bin/chmod 755 "$<TARGET_FILE_DIR:veyon-server>/${_helper}"
				COMMENT "Embedding ${_helper} into veyon-server bundle"
				VERBATIM
			)
		endif()
	endforeach()
	unset(_veyon_macos_helpers)
endif()
