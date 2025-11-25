# NetworkControl Plugin for Veyon

Plugin que permite deshabilitar/habilitar la conexión a internet en computadoras clientes mientras mantiene la red local funcionando.

## Funcionalidad

### 🔴 Disable Internet
Bloquea el acceso a internet eliminando la ruta por defecto (gateway) del sistema operativo.
- **Ventaja:** La red local sigue funcionando, por lo que Veyon permanece conectado
- **Implementación:** Ejecuta `route -n delete default` mediante helper script privilegiado
- **Estado:** Guarda gateway en `/tmp/veyon-network-control-gateway` para poder restaurarlo

### 🟢 Enable Internet
Restaura el acceso a internet añadiendo de nuevo la ruta por defecto.
- **Implementación:** Ejecuta `route -n add default <gateway>` con información guardada
- **Limpieza:** Elimina archivos temporales al finalizar

## Arquitectura Técnica

### Componentes

```
Plugin (networkcontrol.dylib)
   ↓
sudo /usr/local/bin/veyon-network-helper {disable|enable}
   ↓
/sbin/route {delete|add} default
```

**Sin popup de contraseña:** Configurado mediante `/etc/sudoers.d/veyon-network-control`

### Archivos

- **Plugin:** `/Applications/Veyon/veyon-{master|server}.app/Contents/lib/veyon/networkcontrol.dylib`
- **Helper Script:** `/usr/local/bin/veyon-network-helper`
- **Configuración Sudoers:** `/etc/sudoers.d/veyon-network-control`
- **Archivos Temporales:** `/tmp/veyon-network-control-{gateway|active}`

## Compilación

### Requisitos
- Qt5 (`/usr/local/opt/qt@5`)
- Veyon instalado en `/Applications/Veyon/`
- Xcode Command Line Tools

### Compilar

```bash
cd /Users/pablo/GitHub/veyon/plugins/networkcontrol

# Limpiar compilación anterior
make clean 2>/dev/null || true

# Generar Makefile
/usr/local/opt/qt@5/bin/qmake networkcontrol.pro

# Compilar
make -j4

# Renombrar resultado
mv libnetworkcontrol.dylib networkcontrol.dylib

# Corregir rutas de frameworks
install_name_tool -change "@loader_path/qca-qt5" \
  "@executable_path/../Frameworks/qca-qt5.framework/Versions/2/qca-qt5" \
  networkcontrol.dylib
```

### Verificar

```bash
# Ver dependencias
otool -L networkcontrol.dylib

# Verificar recursos embebidos (debería mostrar 2)
strings networkcontrol.dylib | grep "IHDR" | wc -l
```

## Crear Paquete de Distribución

```bash
# 1. Crear estructura
mkdir -p package-build/{payload,scripts}
mkdir -p package-build/payload/{Applications/Veyon/veyon-{master,server}.app/Contents/lib/veyon,usr/local/bin,etc/sudoers.d}

# 2. Copiar archivos
cp networkcontrol.dylib package-build/payload/Applications/Veyon/veyon-master.app/Contents/lib/veyon/
cp networkcontrol.dylib package-build/payload/Applications/Veyon/veyon-server.app/Contents/lib/veyon/
cp veyon-network-helper.sh package-build/payload/usr/local/bin/veyon-network-helper
cp veyon-network-control-sudoers package-build/payload/etc/sudoers.d/veyon-network-control

# 3. Crear script de post-instalación
cat > package-build/scripts/postinstall <<'EOF'
#!/bin/bash
set -e
chmod 755 /Applications/Veyon/veyon-master.app/Contents/lib/veyon/networkcontrol.dylib
chmod 755 /Applications/Veyon/veyon-server.app/Contents/lib/veyon/networkcontrol.dylib
chmod 755 /usr/local/bin/veyon-network-helper
chmod 440 /etc/sudoers.d/veyon-network-control
chown root:wheel /etc/sudoers.d/veyon-network-control
visudo -c -f /etc/sudoers.d/veyon-network-control || rm -f /etc/sudoers.d/veyon-network-control
exit 0
EOF
chmod +x package-build/scripts/postinstall

# 4. Construir paquete
pkgbuild --root package-build/payload \
         --scripts package-build/scripts \
         --identifier io.veyon.networkcontrol \
         --version 2.0.0 \
         --install-location / \
         VeyonNetworkControl-v2.0.0.pkg

# 5. Mover a distribución
mv VeyonNetworkControl-v2.0.0.pkg /Users/pablo/GitHub/veyon/veyon-macos-distribution/
```

## Instalación

```bash
sudo installer -pkg VeyonNetworkControl-v2.0.0.pkg -target /
```

O doble click en el archivo `.pkg` desde Finder.

## Estructura del Código

```
plugins/networkcontrol/
├── NetworkControlFeaturePlugin.h     # Declaración de la clase plugin
├── NetworkControlFeaturePlugin.cpp   # Implementación (disable/enable)
├── networkcontrol.qrc                # Recursos Qt (iconos)
├── network-disabled.png              # Icono rojo (5.6KB)
├── network-enabled.png               # Icono verde (4.2KB)
├── networkcontrol.pro                # Configuración qmake
├── CMakeLists.txt                    # Configuración CMake (no usado)
├── veyon-network-helper.sh           # Script helper privilegiado
├── veyon-network-control-sudoers     # Configuración sudo sin password
└── README.md                         # Este archivo
```

## Seguridad

La configuración sudoers permite ejecutar **únicamente** el helper script sin contraseña:
- Solo dos operaciones: `disable` y `enable`
- No acepta otros comandos
- Limitado a manipulación de rutas de red
- Archivo validado con `visudo` durante instalación

---

**Versión:** 2.0.0
**Compatible con:** Veyon 4.x (Qt5)
**Plataforma:** macOS 10.15+
