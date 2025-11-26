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

## Compilación y Empaquetado

Este plugin soporta tres plataformas: **macOS**, **Linux**, y **Windows**. Cada plataforma tiene su propio proceso de build y empaquetado.

---

### 🍎 macOS

#### Build Automático (Recomendado)

```bash
cd plugins/networkcontrol
./macos-build-and-package.sh
```

El script automáticamente:
- Compila el plugin usando qmake + make
- Crea paquetes `.pkg` con opciones de instalación personalizables
- Los coloca en `veyon-macos-distribution/` (en la raíz del repositorio)

#### Requisitos
- Qt5 (`/usr/local/opt/qt@5`)
- Veyon instalado en `/Applications/Veyon/`
- Xcode Command Line Tools

#### Build Manual

```bash
cd plugins/networkcontrol

# Generar Makefile y compilar
/usr/local/opt/qt@5/bin/qmake networkcontrol.pro
make -j4

# Renombrar y corregir rutas
mv libnetworkcontrol.dylib networkcontrol.dylib
install_name_tool -change "@loader_path/qca-qt5" \
  "@executable_path/../Frameworks/qca-qt5.framework/Versions/2/qca-qt5" \
  networkcontrol.dylib

# Verificar
otool -L networkcontrol.dylib
```

#### Instalación

```bash
# Opción 1: Usar el instalador gráfico
open VeyonNetworkControl-v2.0.0.pkg

# Opción 2: Instalar por línea de comandos
sudo installer -pkg VeyonNetworkControl-v2.0.0.pkg -target /
```

---

### 🐧 Linux

#### Build Automático (Recomendado)

```bash
cd plugins/networkcontrol
./linux-build-and-package.sh
```

El script automáticamente:
- Detecta tu distribución (Debian/Ubuntu o RHEL/Fedora/openSUSE)
- Detecta la versión de Qt (Qt5 o Qt6)
- Compila el plugin usando CMake + Ninja
- Crea el paquete apropiado (`.deb` o `.rpm`)
- Lo coloca en `veyon-linux-distribution/` (en la raíz del repositorio)

#### Requisitos

**Debian/Ubuntu:**
```bash
sudo apt-get install cmake ninja-build dpkg-dev fakeroot
sudo apt-get install qtbase5-dev libqca-qt5-2-dev  # Qt5
# o
sudo apt-get install qt6-base-dev libqca-qt6-dev   # Qt6
```

**Fedora/RHEL:**
```bash
sudo dnf install cmake ninja-build rpm-build fakeroot
sudo dnf install qt5-qtbase-devel qca-qt5-devel    # Qt5
# o
sudo dnf install qt6-qtbase-devel qca-qt6-devel    # Qt6
```

#### Build Manual

```bash
# Desde la raíz del repositorio de Veyon
mkdir build && cd build

# Configurar con CMake
cmake -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=/usr ..

# Compilar solo el plugin
ninja networkcontrol

# El plugin estará en: build/plugins/networkcontrol/libnetworkcontrol.so
```

#### Instalación

**Debian/Ubuntu:**
```bash
sudo dpkg -i veyon-plugin-networkcontrol_2.0.0_amd64.deb
sudo apt-get install -f  # Si hay dependencias faltantes
```

**Fedora/RHEL:**
```bash
sudo rpm -i veyon-plugin-networkcontrol-2.0.0-1.x86_64.rpm
# o
sudo dnf install veyon-plugin-networkcontrol-2.0.0-1.x86_64.rpm
```

---

### 🪟 Windows

#### Nota Importante sobre Windows

El build de Windows en Veyon usa **cross-compilation desde Linux** con MinGW. Es la forma recomendada y más confiable de compilar el plugin.

---

#### Opción 1: Build desde Linux ⭐ (Recomendado)

Este es el método más confiable para crear instaladores de Windows:

**En Linux (Ubuntu/Debian):**

```bash
# 1. Instalar herramientas necesarias
sudo apt-get install cmake ninja-build mingw-w64 nsis

# 2. Compilar y empaquetar
cd plugins/networkcontrol
./windows-cross-compile-and-package.sh x86_64  # Para Windows 64-bit

# El instalador estará en:
# veyon-windows-distribution/VeyonNetworkControl-2.0.0-win64-setup.exe
```

**En Linux (Fedora/RHEL):**

```bash
# 1. Instalar herramientas necesarias
sudo dnf install cmake ninja-build mingw64-gcc mingw64-gcc-c++ nsis

# 2. Compilar y empaquetar
cd plugins/networkcontrol
./windows-cross-compile-and-package.sh x86_64
```

El script automáticamente:
- Compila `networkcontrol.dll` usando MinGW cross-compiler
- Crea un instalador NSIS profesional (`VeyonNetworkControl-2.0.0-win64-setup.exe`)
- El instalador incluye:
  - Detección automática de la instalación de Veyon
  - Backup del plugin anterior
  - Inicio/parada automática del servicio Veyon
  - Entrada en Programas y Características de Windows
  - Desinstalador integrado

**Distribuir el instalador:**

Simplemente copia `VeyonNetworkControl-2.0.0-win64-setup.exe` a las máquinas Windows y ejecútalo como Administrador.

---

#### Opción 2: Crear Instalador desde DLL Pre-compilado

Si ya tienes `networkcontrol.dll` compilado:

**En Windows con NSIS instalado:**

```cmd
REM 1. Descargar e instalar NSIS desde https://nsis.sourceforge.io/

REM 2. Colocar networkcontrol.dll en el directorio del plugin

REM 3. Ejecutar el build script
cd plugins\networkcontrol
windows-build-installer.bat

REM El instalador se creará como:
REM VeyonNetworkControl-2.0.0-win64-setup.exe
```

**Manualmente con NSIS:**

```cmd
REM Colocar networkcontrol.dll en el directorio
REM Ejecutar:
makensis networkcontrol-installer.nsi
```

---

#### Opción 3: Instalación Manual del Plugin (Sin Instalador)

Si solo quieres instalar el plugin sin crear un instalador:

**Usando el script batch:**

```cmd
REM 1. Colocar networkcontrol.dll en el mismo directorio que el script
REM 2. Click derecho en windows-install-plugin.bat -> "Ejecutar como administrador"
```

**Completamente manual:**

```cmd
REM 1. Detener el servicio Veyon
net stop VeyonService

REM 2. Copiar el plugin
copy networkcontrol.dll "C:\Program Files\Veyon\plugins\"

REM 3. Reiniciar el servicio
net start VeyonService
```

---

#### Diferencias en Windows

⚠️ **Importante:** En Windows, el plugin funciona de manera diferente:
- No usa el script `veyon-network-helper` (solo macOS/Linux)
- Usa Windows Firewall o políticas de red del sistema
- Requiere que el Veyon Service esté corriendo
- La configuración se gestiona mediante `veyon-wcli.exe`

---

#### Archivos para Windows

| Archivo | Propósito |
|---------|-----------|
| `windows-cross-compile-and-package.sh` | 🐧 Compilación desde Linux + instalador NSIS |
| `networkcontrol-installer.nsi` | Script NSIS para crear el instalador |
| `windows-build-installer.bat` | Crear instalador en Windows (requiere DLL compilado) |
| `windows-install-plugin.bat` | Instalación manual simple del plugin |

---

## Verificación de Instalación

Independientemente de la plataforma, verifica que el plugin se cargó correctamente:

**macOS:**
```bash
# En Veyon Master, ir a Ayuda -> Acerca de -> Plugins
# o verificar los logs
log show --predicate 'process == "veyon-master"' --last 5m | grep -i network
```

**Linux:**
```bash
# Verificar que el archivo existe
ls -l /usr/lib/*/veyon/networkcontrol.so
ls -l /usr/local/bin/veyon-network-helper

# Verificar sudoers
sudo visudo -c -f /etc/sudoers.d/veyon-network-control
```

**Windows:**
```cmd
REM Verificar que el archivo existe
dir "C:\Program Files\Veyon\plugins\networkcontrol.dll"
```

## Estructura del Código

```
plugins/networkcontrol/
├── NetworkControlFeaturePlugin.h        # Declaración de la clase plugin
├── NetworkControlFeaturePlugin.cpp      # Implementación (disable/enable)
├── networkcontrol.qrc                   # Recursos Qt (iconos)
├── network-disabled.png                 # Icono rojo (estado deshabilitado)
├── network-enabled.png                  # Icono verde (estado habilitado)
├── network-disabled.svg                 # Fuente SVG del icono rojo
├── network-enabled.svg                  # Fuente SVG del icono verde
├── networkcontrol.pro                   # Configuración qmake (macOS)
├── CMakeLists.txt                       # Configuración CMake (Linux/oficial)
├── veyon-network-helper.sh              # Script helper privilegiado (macOS/Linux)
├── veyon-network-control-sudoers        # Configuración sudo sin password
├── macos-build-and-package.sh           # Build automático para macOS
├── linux-build-and-package.sh           # Build automático para Linux
├── windows-cross-compile-and-package.sh # Build desde Linux para Windows
├── networkcontrol-installer.nsi         # Script NSIS para instalador Windows
├── windows-build-installer.bat          # Crear instalador NSIS en Windows
├── windows-install-plugin.bat           # Instalación manual en Windows
└── README.md                            # Este archivo
```

## Seguridad

La configuración sudoers permite ejecutar **únicamente** el helper script sin contraseña:
- Solo dos operaciones: `disable` y `enable`
- No acepta otros comandos
- Limitado a manipulación de rutas de red
- Archivo validado con `visudo` durante instalación

---

## Scripts de Build Disponibles

| Script | Plataforma | Función |
|--------|-----------|---------|
| `macos-build-and-package.sh` | macOS | Compila y crea paquetes `.pkg` |
| `linux-build-and-package.sh` | Linux | Compila y crea paquetes `.deb`/`.rpm` |
| `windows-cross-compile-and-package.sh` | Linux→Windows | Cross-compila y crea instalador `.exe` |
| `networkcontrol-installer.nsi` | Windows | Script NSIS para crear instalador |
| `windows-build-installer.bat` | Windows | Crea instalador desde DLL compilado |
| `windows-install-plugin.bat` | Windows | Instala plugin manualmente |

---

**Versión:** 2.0.0
**Compatible con:** Veyon 4.x (Qt5/Qt6)
**Plataformas:** macOS 10.15+, Linux (Debian/Ubuntu, Fedora/RHEL, openSUSE), Windows 10+
