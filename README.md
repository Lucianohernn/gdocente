# GDocente — Hito 3

Aplicación Flutter (Android) para que un docente organice **Carreras → Materias (por año) → Alumnos**, tome **asistencia**, cargue **evaluaciones y notas**, y le prepare a cada alumno un mensaje individual por **WhatsApp** con su situación (asistencia, promedio y evaluaciones a recuperar). Permite exportar cada materia a **Excel** e importar alumnos desde Excel. Los datos se guardan localmente en SQLite (sqflite).

Versión: **1.2.1+5**.

## Funciones

| Función | Dónde | Hito |
|---|---|---|
| Carreras, materias por año y alumnos (alta, edición, baja lógica, búsqueda) | Pantallas principales | 2 |
| Mensaje individual por WhatsApp, revisado por el docente antes de enviar | Ícono de chat en cada alumno | 2 |
| Asistencia por fecha: **P**resente, **A**usente, **T**arde, **J**ustificada | Alumnos → ícono ✅ | 3 |
| Evaluaciones de la materia y planilla de notas con recuperatorio | Alumnos → ícono 📋 | 3 |
| Resumen por alumno (asistencia %, promedio, a recuperar) en la lista y en el mensaje de WhatsApp | Lista de alumnos | 3 |
| Exportar la materia a Excel (.xlsx) y compartirlo (Drive, WhatsApp, correo) | Alumnos → ⋮ → Exportar | 3 |
| Importar desde Excel: alumnos, asistencias y notas (respaldo completo o pasar los datos a otro celular) | Alumnos → ⋮ → Importar | 3 |

### Reglas de cálculo

- **Asistencia %** = clases asistidas / clases que cuentan × 100.
  - *Clases asistidas* = presentes + llegadas tarde.
  - *Clases que cuentan* = presentes + llegadas tarde + ausentes. Las faltas **justificadas no cuentan** ni a favor ni en contra.
  - Si el alumno todavía no tiene clases que cuenten, el porcentaje queda vacío.
- **Nota final** de una evaluación: si hay **recuperatorio, reemplaza** a la nota original. Se permite recuperatorio sin nota original (el alumno faltó al examen).
- **Promedio**: de las evaluaciones que tienen nota final. Las que no tienen nota no cuentan.
- **A recuperar**: evaluaciones con nota final **menor a 6**.
- Las notas van de **1 a 10** y admiten decimales con coma o punto (7,5).

La lógica está en `lib/services/resumen_academico.dart` y es pura (no usa base de datos ni pantalla), por eso tiene pruebas unitarias.

### Excel

**Exportar** genera `GDocente_<materia>_<año>anio_<fecha>.xlsx` con 4 hojas:

| Hoja | Contenido |
|---|---|
| Resumen | Alumno, teléfono, asistencia %, clases asistidas, clases que cuentan, justificadas, promedio, a recuperar; al pie, la explicación de cada cálculo |
| Asistencia | Una columna por clase con P / A / T / J |
| Notas | Nota y recuperatorio de cada evaluación |
| Alumnos | Nombre completo y teléfono (mismo formato que la importación: sirve de plantilla) |

**Importar** acepta dos formatos:

- **Excel exportado por GDocente** → recupera **alumnos, asistencias y notas**. Sirve como respaldo completo o para pasar una materia a otro celular: se exporta en uno y se importa en una materia del otro.
- **Lista simple** → **columna A** nombre completo, **columna B** teléfono (en la hoja "Alumnos" o en la primera hoja). La primera fila puede ser el encabezado.

Reglas al importar:

- Los alumnos pasan por las mismas validaciones que el alta manual. Si ya hay un alumno con el **mismo nombre** en la materia, se mantiene el existente.
- Las asistencias y notas se asocian a los alumnos **por nombre completo** (sin importar mayúsculas ni espacios de más).
- Si ya había asistencia de ese alumno en esa fecha, o nota en esa evaluación, **la del Excel la reemplaza**. Las evaluaciones se buscan por nombre y, si no existen, se crean.
- Las fechas pueden venir como texto (07/11/2026) o como celda de fecha, por si el archivo se editó en Excel o Google Sheets.
- Lo que no se pudo importar (teléfono inválido, código de asistencia distinto de P/A/T/J, nota fuera de 1 a 10, alumno que no existe) se informa al final.

La lectura del archivo está en `lib/services/lector_excel.dart`, que es lógica pura y tiene pruebas; la parte que guarda en la base está en `excel_service.dart`.

## Cómo correrlo (Windows + VS Code)

```bash
cd ~/Documents/gdocente
flutter pub get
flutter test                         # pruebas unitarias
flutter run                          # con el celular conectado o el emulador abierto
```

Con `flutter run` andando: `r` aplica los cambios al instante (*hot reload*), `R` reinicia la app y `q` sale.

> Primera vez en una PC nueva: `flutter create --org com.hermann --project-name gdocente --platforms android .` genera las carpetas nativas sin pisar los archivos existentes, y `dart run flutter_launcher_icons` genera el ícono.

### Probar en un celular Xiaomi / POCO (HyperOS)

En *Opciones de desarrollador* activar **Depuración USB**, **Instalar vía USB** y **Depuración USB (ajustes de seguridad)** (pide cuenta Mi y datos móviles). Al instalar desde la PC el celular tiene que estar **desbloqueado y con la pantalla prendida**; si no, cancela la instalación con `INSTALL_FAILED_USER_RESTRICTED`.

El celular resulta mucho más rápido que el emulador para probar.

## Generar el APK

```bash
flutter build apk --release
```

Resultado: `build/app/outputs/flutter-apk/app-release.apk` (se instala copiándolo al celular).
Versión más liviana por arquitectura: `flutter build apk --release --split-per-abi` → `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

## Firma de la app (clave propia)

Android solo deja instalar una versión nueva **encima** de la anterior, conservando los datos, si las dos están firmadas con **la misma clave**. Por eso la app se firma con una clave propia y no con la clave de prueba de la PC.

**Crear la clave (una sola vez)**, desde la carpeta del proyecto:

```bash
powershell -ExecutionPolicy Bypass -File tools\crear_clave.ps1
```

El script pide una contraseña y genera:

- `..\gdocente-clave\gdocente.jks`: la clave. Queda **fuera** del proyecto para no compartirla junto con el código.
- `android\key.properties`: le indica a Gradle dónde está la clave y cuál es su contraseña. Está en `.gitignore`.

Desde ese momento, `flutter build apk --release` y `flutter run` firman con esa clave. Las dos usan la misma, así el celular de desarrollo puede pasar de una a otra sin desinstalar. Si `key.properties` no existe, se firma con la clave de prueba.

> ⚠️ **Guardar una copia** de la carpeta `gdocente-clave` y de la contraseña en un lugar seguro (Drive, pendrive). Si se pierden, las versiones nuevas no se van a poder instalar encima de la que ya tienen los docentes, y cada docente tendría que desinstalar la app y perder sus datos.

## Distribución a otros docentes y actualizaciones

Los docentes **no** necesitan activar la depuración USB: eso solo hace falta para instalar desde la PC con un cable.

**Primera instalación (APK por WhatsApp o Drive):** abrir el archivo → permitir "instalar apps de esta fuente" (una sola vez) → **Instalar**. Si Play Protect avisa "app desconocida": **Más detalles → Instalar de todas formas**.

**Firebase App Distribution** (gratis): se sube el APK en [console.firebase.google.com](https://console.firebase.google.com) → proyecto → *App Distribution*, y se agregan los correos de los docentes. Cada uno recibe un correo con el enlace de instalación, y Firebase le avisa cuando hay una versión nueva. Para esto la app no necesita ningún código de Firebase.

**Cada actualización conserva los datos de los alumnos** si se cumplen tres condiciones:

1. Mismo identificador: `com.hermann.gdocente` (no se cambia nunca).
2. Misma clave de firma (`gdocente.jks`).
3. Número de compilación **mayor**: el `+N` de `version:` en `pubspec.yaml` (por ejemplo, `1.2.0+4` → `1.2.1+5`).

> **Distribuir siempre el APK universal** (`app-release.apk`, ~50 MB, funciona en cualquier celular). Los APK de `--split-per-abi` se numeran distinto (arm64 = 2000 + N): si un docente instala uno de esos y después recibe el universal, Android lo toma como una versión *más vieja* y no lo instala. Hay que elegir un solo tipo y no mezclarlos.

Si una versión nueva cambia la base de datos, se sube `_version` en `app_database.dart` y se agrega el paso correspondiente en `onUpgrade`, como se hizo en el Hito 3. Nunca se borran tablas.

## Arquitectura en capas

```
lib/
├── main.dart                     # Punto de entrada, tema, idioma español
├── screens/                      # Presentación (UI): no conocen SQL
│   ├── carreras_screen.dart
│   ├── materias_screen.dart
│   ├── alumnos_screen.dart       # + resumen, accesos a asistencia/notas, Excel
│   ├── alumno_form_screen.dart
│   ├── asistencia_screen.dart    # Hito 3
│   ├── evaluaciones_screen.dart  # Hito 3
│   └── notas_screen.dart         # Hito 3
├── widgets/                      # Componentes reutilizables (diálogo WhatsApp, helpers)
├── services/                     # Reglas de negocio y validaciones
│   ├── resumen_academico.dart    # Cálculo puro de asistencia, promedio y a recuperar
│   ├── resumen_service.dart      # Arma los resúmenes de una materia (3 consultas)
│   ├── excel_service.dart        # Exportación / importación .xlsx
│   └── ...                       # carrera, materia, alumno, asistencia, evaluación, whatsapp
├── dao/                          # Único lugar con SQL (CRUD parametrizado)
├── models/                       # Filas como objetos (toMap / fromMap)
├── database/app_database.dart    # Singleton de conexión SQLite + migraciones
└── utils/
    ├── telefono.dart             # Normalización de teléfonos para wa.me
    └── formato.dart              # Fechas dd/MM/yyyy y notas con coma decimal
```

## Base de datos

Versión de esquema **2**. Las instalaciones del Hito 2 se actualizan solas (`onUpgrade`) sin perder datos.

| Tabla | Columnas principales | Relación |
|---|---|---|
| carreras | nombre (único) | — |
| materias | carrera_id, nombre, anio | carrera: RESTRICT |
| alumnos | materia_id, nombre_completo, telefono, fecha_alta, activo | materia: CASCADE |
| asistencias | alumno_id, fecha (yyyy-MM-dd), estado (P/A/T/J) · único por alumno y fecha | alumno: CASCADE |
| evaluaciones | materia_id, nombre, fecha · nombre único por materia | materia: CASCADE |
| notas | evaluacion_id, alumno_id, nota, recuperatorio · única por evaluación y alumno | evaluación y alumno: CASCADE |

La asistencia de un día y la planilla de notas se guardan en **una sola transacción**: si algo falla, no queda la mitad guardada. Como la baja de alumnos es lógica, sus asistencias y notas se conservan.

## Pruebas

`flutter test` corre 22 pruebas unitarias:

- `test/widget_test.dart`: normalización y formato de teléfonos.
- `test/lector_excel_test.dart`: lectura del Excel exportado (alumnos, asistencias y notas con recuperatorio), lista simple, teléfonos guardados como número, fechas como celda de fecha, avisos por datos inválidos y archivo que no es Excel.
- `test/resumen_test.dart`: porcentaje de asistencia (tardes y justificadas), recuperatorio que reemplaza la nota, promedio sin evaluaciones vacías, límite de aprobación (6 aprueba, 5,99 no), validación de notas, formato de fechas y números, y el texto del mensaje de WhatsApp.

## Bitácora de errores del tutorial corregidos

| # | En el tutorial | Problema | Solución en GDocente |
|---|---|---|---|
| 1 | `applicationId "com.x"` en `build.gradle` | Los proyectos nuevos usan `build.gradle.kts` (Kotlin): esa sintaxis no compila | Se define con `flutter create --org com.hermann` (o `applicationId = "..."` en `.kts`) |
| 2 | `flutter pub run flutter_launcher_icons` | Comando deprecado | `dart run flutter_launcher_icons` |
| 3 | `canLaunchUrl` sin `<queries>` | En Android 11+ devuelve `false` y WhatsApp no abre | `<queries>` en el `AndroidManifest.xml` + `LaunchMode.externalApplication` |
| 4 | "wa.me no depende del formato del número" | Falso: exige formato internacional sin `+`, 0 ni 15 | `Telefono.normalizar()` guarda `549` + área + número, con pruebas |
| 5 | `PRAGMA foreign_keys = ON` solo mencionado | Las FK no se aplican | `onConfigure` en `openDatabase` |
| 6 | Ruta de APKs split en `apk/release/` | Inconsistente con el paso de instalación | La ruta real es `build/app/outputs/flutter-apk/` |
| 7 | `Navigator.pop(context)` después de `await` | Lint `use_build_context_synchronously`, posible crash | `if (!mounted) return;` antes de usar `context` |
| 8 | `flutter_lints ^3`, `flutter_launcher_icons ^0.13` | Versiones viejas | `^5.0.0` y `^0.14.1` |
| 9 | `test/widget_test.dart` generado por `flutter create` | Referencia `MyApp`, que no existe → error en `flutter analyze` | Se reemplaza por pruebas unitarias propias |
| 10 | `ndkVersion = flutter.ndkVersion` | Pedía el NDK 28.2, que no estaba instalado, y la descarga automática fallaba ("Package ndk not found") | `ndkVersion = "30.0.16248370"` (el NDK ya instalado) en `android/app/build.gradle.kts` |
| 11 | Agregar tablas cambiando solo el `CREATE TABLE` | En celulares con la app ya instalada `onCreate` no se vuelve a ejecutar: las tablas nuevas no existirían | Versión de esquema 2 + `onUpgrade` que crea las tablas del Hito 3 |
| 12 | `showDatePicker` sin localización | El calendario aparece en inglés | `flutter_localizations` + `locale: es_AR` en `MaterialApp` |
| 13 | «Deshacer» una baja después de importar el mismo alumno | Quedaba duplicado (dos activos con el mismo teléfono) | `deshacerBaja` valida el teléfono igual que el alta y avisa si se repite |
| 14 | Contador «N nota(s) cargada(s)» de cada evaluación | Contaba las notas de alumnos dados de baja | La consulta solo cuenta notas de alumnos activos |

## Alcance

La **versión para Windows** prevista en el Hito 1 queda fuera del proyecto: compilar para escritorio requiere instalar Visual Studio con "Desarrollo para el escritorio con C++" (unos 8 GB), y no hay espacio disponible en la PC de desarrollo. Como respaldo y para trabajar los datos en la computadora se usa la **exportación a Excel**.
