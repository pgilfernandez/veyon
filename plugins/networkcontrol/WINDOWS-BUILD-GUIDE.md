# Guía Rápida: Compilar e Instalar para Windows

Esta guía te muestra cómo crear un instalador `.exe` para el plugin NetworkControl en Windows.

## 🎯 Resumen Rápido

Para distribuir el plugin en Windows, necesitas crear un **instalador NSIS** (`.exe`) que los usuarios puedan ejecutar.

## 📋 Opción 1: Build desde Linux ⭐

### Requisitos
- **Sistema:** Linux (Ubuntu, Debian, Fedora, etc.)
- **Herramientas:**
  ```bash
  # En Ubuntu/Debian:
  sudo apt-get install cmake ninja-build mingw-w64 nsis

  # En Fedora/RHEL:
  sudo dnf install cmake ninja-build mingw64-gcc mingw64-gcc-c++ nsis
  ```

### Pasos

1. **Ejecutar el script de compilación:**
   ```bash
   cd plugins/networkcontrol
   ./windows-cross-compile-and-package.sh x86_64
   ```

2. **Resultado:**
   - Se crea: `veyon-windows-distribution/VeyonNetworkControl-2.0.0-win64-setup.exe`
   - Tamaño: ~50-100 KB
   - Listo para distribuir

3. **Distribuir:**
   - Copia el `.exe` a las máquinas Windows
   - Ejecuta como Administrador
   - ¡Listo!

---

## 📋 Opción 2: Crear Instalador desde DLL Pre-compilado

Si ya tienes `networkcontrol.dll` compilado (por ejemplo, del CI de Veyon):

### En Windows

1. **Instalar NSIS:**
   - Descargar: https://nsis.sourceforge.io/Download
   - Instalar y agregar a PATH

2. **Preparar archivos:**
   ```cmd
   REM Copiar networkcontrol.dll al directorio del plugin
   copy path\to\networkcontrol.dll plugins\networkcontrol\
   cd plugins\networkcontrol
   ```

3. **Crear instalador:**
   ```cmd
   REM Opción A: Usar el script batch
   windows-build-installer.bat

   REM Opción B: Directamente con NSIS
   makensis networkcontrol-installer.nsi
   ```

4. **Resultado:**
   - Se crea: `VeyonNetworkControl-2.0.0-win64-setup.exe`

---

## 📋 Opción 3: Instalación Manual (Sin Instalador)

Si solo quieres instalar en una máquina sin crear instalador:

1. **Obtener el DLL:**
   - Compilar con cross-compilation, o
   - Descargar de un build de CI

2. **Instalar:**
   ```cmd
   REM Opción A: Usar el script
   REM (Colocar networkcontrol.dll en el mismo directorio)
   windows-install-plugin.bat  (ejecutar como Administrador)

   REM Opción B: Manual
   net stop VeyonService
   copy networkcontrol.dll "C:\Program Files\Veyon\plugins\"
   net start VeyonService
   ```

---

## 🔧 Compilación Avanzada

### Solo compilar el DLL (sin instalador)

Desde Linux con el build system de Veyon:

```bash
cd /ruta/a/veyon
.ci/windows/build.sh x86_64

# El DLL estará en:
# build/plugins/networkcontrol/networkcontrol.dll
```

---

## 📦 Contenido del Instalador NSIS

El instalador `.exe` creado incluye:

✅ Detección automática de Veyon
✅ Detiene/inicia el servicio automáticamente
✅ Hace backup del plugin anterior
✅ Se registra en "Programas y características"
✅ Incluye desinstalador
✅ Verifica permisos de administrador

---

## ❓ Preguntas Frecuentes

### ¿Por qué cross-compilation desde Linux?

Veyon usa MinGW para compilar para Windows, lo cual es más fácil desde Linux. Compilar directamente en Windows requeriría configurar todo el toolchain de MinGW en Windows, lo cual es complejo.

### ¿Puedo compilar en macOS para Windows?

**No directamente.** Requeriría Qt compilado para MinGW, que no está disponible en Homebrew y es muy complejo de configurar manualmente.

**Alternativas desde macOS:**
1. Usar una VM Linux (UTM, Parallels, VirtualBox)
2. Usar Docker con un contenedor Linux
3. Compilar directamente en una máquina Windows

### ¿El instalador funciona en Windows 32-bit?

El script por defecto crea instaladores 64-bit. Para 32-bit, ejecuta:
```bash
./windows-cross-compile-and-package.sh i686
```

### ¿Necesito instalar Veyon primero?

Sí, el plugin requiere que Veyon esté instalado. El instalador lo detecta automáticamente.

---

## 🛠️ Troubleshooting

### Error: "NSIS not found"

**Solución:**
```bash
# Ubuntu/Debian
sudo apt-get install nsis

# Fedora/RHEL
sudo dnf install nsis
```

### Error: "MinGW compiler not found"

**Solución:**
```bash
# Ubuntu/Debian
sudo apt-get install mingw-w64

# Fedora/RHEL
sudo dnf install mingw64-gcc mingw64-gcc-c++
```

### El instalador no detecta Veyon

**Solución:** El instalador busca en `C:\Program Files\Veyon`. Si Veyon está en otra ubicación, puedes:
1. Cambiar el directorio durante la instalación
2. Modificar `INSTDIR` en el script `.nsi`

---

## 📚 Archivos Relacionados

| Archivo | Descripción |
|---------|-------------|
| `windows-cross-compile-and-package.sh` | Script principal (Linux→Windows) |
| `networkcontrol-installer.nsi` | Script NSIS |
| `windows-build-installer.bat` | Build en Windows |
| `windows-install-plugin.bat` | Instalación manual |
| `README.md` | Documentación completa |

---

**¿Necesitas ayuda?** Consulta el [README.md](README.md) completo para más detalles.
