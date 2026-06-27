# Mosca — Rastreador de finanzas personales

Mosca es una aplicación móvil de finanzas personales construida con Flutter, diseñada para el contexto colombiano. Permite registrar, categorizar y analizar gastos e ingresos, con sincronización automática desde el correo de Gmail de los bancos más usados en Colombia.

---

## Tabla de contenidos

1. [Características](#características)
2. [Arquitectura técnica](#arquitectura-técnica)
3. [Stack tecnológico](#stack-tecnológico)
4. [Estructura del proyecto](#estructura-del-proyecto)
5. [Configuración de secretos](#configuración-de-secretos)
6. [Cómo correr el proyecto](#cómo-correr-el-proyecto)
7. [Base de datos](#base-de-datos)
8. [Decisiones de diseño](#decisiones-de-diseño)

---

## Características

### Registro de gastos e ingresos
- Registro manual con monto, categoría, descripción, notas y fecha personalizable.
- Soporte para pesos colombianos (COP) con formato `#,##0`.
- Foto de recibo adjuntable a cada transacción.
- Deshacer eliminación via SnackBar con acción de restauración.
- Búsqueda en tiempo real sobre el historial.

### Sincronización con Gmail
- Conexión con Google Sign-In (solo lectura de Gmail).
- Parseo automático de correos de transacciones de: **Bancolombia**, **Nequi**, **Davivienda**, **BBVA**, **Nu (Nubank)** y **Falabella**.
- Detección de duplicados para evitar registros repetidos.
- Cada transacción parseada se vincula al `gmail_message_id` original.

### Categorías
- Categorías predeterminadas de gastos e ingresos (Comida, Transporte, Salud, Salario, etc.).
- Categorías personalizadas con nombre, color de paleta e ícono del sistema (Material Icons).
- El ícono se muestra en el color de acento de la categoría (sin la colorimetría del teclado emoji).
- Las categorías personalizadas persisten en base de datos y se comparten en todas las pantallas.

### Período de pago configurable (fecha de corte)
- Configurable desde la pantalla de ajustes (días disponibles: 5, 10, 15, 20, 25, 26, 27, 28).
- Cuando la fecha de corte es, por ejemplo, el 26, el salario recibido el 26 de junio se contabiliza en el período de **julio** (26 jun – 25 jul).
- Todos los totales, gráficas y filtros respetan el período activo.

### Estadísticas
- Resumen mensual: total de gastos, ingresos y balance.
- Gráfica de barras comparativa ingresos vs. gastos (12 meses).
- Gráfica de líneas de tendencia (últimos 6 meses).
- Desglose por categoría con gráfica de torta y barra de progreso.
- Comparación mes a mes por categoría (variación absoluta).
- Al abrir el detalle de una categoría el botón flotante de agregar desaparece automáticamente.

### Presupuestos
- Límite de gasto mensual por categoría.
- Barra de progreso con semáforo: verde < 80%, naranja 80–100%, rojo > 100%.
- Notificaciones push cuando se alcanza el 80% o se supera el límite.

### Gastos recurrentes
- Alta de gastos/ingresos que se repiten en un día fijo del mes.
- Procesamiento automático al abrir la app: si el gasto del mes aún no fue registrado, se crea automáticamente.

### Metas de ahorro
- Metas con nombre, monto objetivo y monto ahorrado.
- Barra de progreso y visualización del porcentaje alcanzado.

### Deudas compartidas
- Registro de deudas a nombre propio compartidas con otra persona.
- Marcado de pago mensual por deuda.
- Notificaciones de recordatorio en la fecha de vencimiento.
- Resumen en pantalla principal con monto pendiente del mes.

### División de gastos
- División de cualquier gasto entre múltiples personas (sin límite).
- Chips de división rápida: ÷2, ÷3, ÷4, ÷5, ÷6 (partes iguales con resto en el primero).
- División personalizada: cada persona puede tener un monto diferente.
- Validación: ninguna parte puede superar el total del gasto.
- Cobro directo via WhatsApp: abre el chat del contacto con el mensaje prellenado.
- Los favoritos del historial aparecen como chips para selección rápida.

### Proyección de flujo de caja
- Cálculo del balance proyectado del mes basado en ingresos y gastos recurrentes configurados.

### Seguridad
- Autenticación biométrica (Face ID / huella) al abrir la app (opcional).

### Widget de pantalla de inicio (iOS)
- Widget nativo iOS que muestra el balance actual del mes sin necesidad de abrir la app.
- Actualización automática al registrar o modificar transacciones.

### Live Activity / Dynamic Island (iOS)
- Actividad en vivo que se muestra en la Dynamic Island / pantalla de bloqueo al registrar un gasto rápido.

---

## Arquitectura técnica

El proyecto sigue una arquitectura de **feature-first** con separación en capas dentro de cada feature:

```
feature/
  data/
    models/       — entidades de dominio y DTOs
    repositories/ — interfaces abstractas + implementaciones SQLite
  domain/
    services/     — lógica de negocio pura (sin Flutter)
  presentation/
    providers/    — estado con Riverpod
    screens/      — pantallas
    widgets/      — widgets específicos del feature
```

Los componentes compartidos entre features viven en:

```
lib/
  core/
    config/    — AppSecrets (git-ignorado, generado por script)
    db/        — DatabaseService (SQLite, migraciones versionadas)
    providers/ — providers globales (payPeriodDayProvider, etc.)
    router/    — GoRouter + Shell con nav bar y FAB
    services/  — NotificationService, HomeWidgetService
    theme/     — AppTheme, AppColors
    utils/     — CurrencyFormatter, DateFormatter, PeriodUtils, ThousandsInputFormatter
  shared/
    widgets/   — CategorySelectorField y otros widgets reutilizables
    extensions/
```

### Flujo de datos

```
UI (ConsumerWidget)
  → ref.watch(provider)        — suscripción reactiva
  → StreamProvider/AsyncNotifierProvider
  → Repository (interface)
  → SqfliteRepository          — SQLite via sqflite
  → DatabaseService._db        — instancia única de la DB
```

Los repositorios exponen `Stream` usando un `StreamController.broadcast()` interno: cuando cualquier escritura ocurre, el controlador emite y todos los watchers se reconstruyen automáticamente.

### Manejo del período de pago

`PeriodUtils.range(year, month, cutDay)` calcula el rango `[start, end]` del período. El repositorio de gastos expone `watchPeriod(DateTime start, DateTime end)` que filtra por `millisecondsSinceEpoch`. Esto permite que el período "26 jun – 25 jul" funcione correctamente aunque cruce meses de calendario.

---

## Stack tecnológico

| Categoría | Librería | Versión |
|---|---|---|
| UI | Flutter | SDK ^3.11.4 |
| Estado | flutter_riverpod | ^2.6.1 |
| Navegación | go_router | ^14.8.1 |
| Base de datos | sqflite | ^2.4.2 |
| HTTP | dio | ^5.8.0+1 |
| Google Auth | google_sign_in | ^6.3.0 |
| Notificaciones | flutter_local_notifications | ^18.0.1 |
| Gráficas | fl_chart | ^0.70.2 |
| Fuentes | google_fonts | ^6.2.1 |
| Internacionalización | intl | ^0.20.2 |
| Biometría | local_auth | ^2.3.0 |
| Compartir | share_plus | ^10.1.0 |
| Links externos | url_launcher | ^6.3.2 |
| Widget iOS | home_widget | ^0.7.0 |
| Live Activity | live_activities | ^2.4.9 |
| Foto de recibo | image_picker | ^1.1.2 |
| Splash | flutter_native_splash | ^2.4.3 |

---

## Estructura del proyecto

```
mosca/
├── android/                        — proyecto Android
├── ios/
│   ├── Runner/
│   │   ├── Info.plist              — configuración iOS (URL schemes, permisos)
│   │   ├── GoogleService-Info.plist — generado por setup_secrets.sh (git-ignorado)
│   │   └── GoogleService-Info.plist.template
│   └── MoscaWidget/                — extensión de widget nativo iOS
├── assets/
│   ├── logo/                       — SVGs del logo (icon.svg, logo.svg, etc.)
│   └── splash/
│       └── splash_icon.png         — ícono usado en launcher y en la app
├── lib/
│   ├── main.dart                   — inicialización, DB, providers override
│   ├── app.dart                    — MaterialApp con tema y router
│   ├── core/
│   │   ├── config/
│   │   │   ├── app_secrets.dart         — git-ignorado, generado por script
│   │   │   └── app_secrets.example.dart — template para nuevos contribuidores
│   │   ├── db/database_service.dart     — SQLite, migraciones v1→v11
│   │   ├── providers/pay_period_provider.dart
│   │   ├── router/app_router.dart       — GoRouter + _Shell (nav bar, FAB)
│   │   ├── services/
│   │   │   ├── notification_service.dart
│   │   │   └── home_widget_service.dart
│   │   ├── theme/
│   │   │   ├── app_theme.dart
│   │   │   └── app_colors.dart
│   │   └── utils/
│   │       ├── currency_formatter.dart
│   │       ├── date_formatter.dart
│   │       ├── period_utils.dart
│   │       └── thousands_formatter.dart
│   ├── features/
│   │   ├── expenses/               — gastos, ingresos, categorías
│   │   ├── stats/                  — estadísticas y gráficas
│   │   ├── budgets/                — presupuestos por categoría
│   │   ├── recurring/              — gastos/ingresos recurrentes
│   │   ├── savings/                — metas de ahorro
│   │   ├── shared_debts/           — deudas compartidas
│   │   ├── splits/                 — división de gastos
│   │   ├── projection/             — proyección de flujo de caja
│   │   ├── gmail_sync/             — sincronización con Gmail
│   │   └── quick_add/              — registro rápido + Live Activity
│   └── shared/
│       └── widgets/
│           └── category_selector_field.dart
├── scripts/
│   └── setup_secrets.sh            — inyecta secretos en los archivos correctos
├── secrets.env                     — git-ignorado, tus claves reales
└── secrets.env.example             — template con instrucciones
```

---

## Configuración de secretos

La app usa Google Sign-In para leer Gmail. Las credenciales OAuth **no se suben al repositorio**.

### Paso 1 — Crear credenciales en Google Cloud Console

1. Ir a [console.cloud.google.com/apis/credentials](https://console.cloud.google.com/apis/credentials)
2. Crear un proyecto (o usar uno existente)
3. Habilitar la API **Gmail API**
4. Crear credencial → **OAuth 2.0 Client ID** → tipo **Web application** → copiar el Client ID
5. Crear credencial → **OAuth 2.0 Client ID** → tipo **iOS** → ingresar el bundle ID de tu app → copiar el Client ID

### Paso 2 — Configurar secrets.env

```bash
cp secrets.env.example secrets.env
```

Editar `secrets.env` con los valores obtenidos:

```bash
GOOGLE_SERVER_CLIENT_ID=tu_web_client_id.apps.googleusercontent.com
GOOGLE_IOS_CLIENT_ID=tu_ios_client_id.apps.googleusercontent.com
GOOGLE_REVERSED_CLIENT_ID=com.googleusercontent.apps.tu_ios_client_id
BUNDLE_ID=com.tuempresa.mosca
APP_GROUP_ID=group.com.tuempresa.mosca
```

### Paso 3 — Ejecutar el script

```bash
bash scripts/setup_secrets.sh
```

El script genera automáticamente:
- `lib/core/config/app_secrets.dart` — constantes Dart con tus credenciales
- `ios/Runner/GoogleService-Info.plist` — archivo de configuración iOS de Google
- Parcha `ios/Runner/Info.plist` con el URL scheme del cliente iOS

Todos los archivos generados están en `.gitignore` y nunca se subirán al repositorio.

---

## Cómo correr el proyecto

### Requisitos previos

| Herramienta | Versión mínima |
|---|---|
| Flutter | 3.24+ |
| Dart | 3.11+ |
| Xcode | 15+ (para iOS) |
| Android Studio / SDK | API 21+ |
| CocoaPods | 1.14+ |

### Instalación

```bash
# 1. Clonar el repositorio
git clone https://github.com/tu-usuario/mosca.git
cd mosca

# 2. Instalar dependencias Dart
flutter pub get

# 3. Instalar pods iOS
cd ios && pod install && cd ..

# 4. Configurar secretos (ver sección anterior)
cp secrets.env.example secrets.env
# editar secrets.env con tus credenciales
bash scripts/setup_secrets.sh

# 5. Correr la app
flutter run
```

### Correr en dispositivo/simulador específico

```bash
# Listar dispositivos disponibles
flutter devices

# iOS
flutter run -d "iPhone 16"

# Android
flutter run -d emulator-5554
```

### Build de release

```bash
# iOS (requiere cuenta de Apple Developer)
flutter build ios --release

# Android APK
flutter build apk --release

# Android App Bundle (para Play Store)
flutter build appbundle --release
```

### Regenerar el splash screen o ícono de la app

```bash
# Splash screen
flutter pub run flutter_native_splash:create

# Ícono de la app (modifica assets/splash/splash_icon.png primero)
flutter pub run flutter_launcher_icons
```

---

## Base de datos

La app usa **SQLite** via `sqflite`. La base de datos se crea en el directorio de documentos de la app (`mosca.db`) y es completamente local — ningún dato sale del dispositivo salvo la autenticación con Google para leer Gmail.

### Tablas principales

| Tabla | Descripción |
|---|---|
| `expenses` | Gastos e ingresos. Campo `type`: `'expense'` o `'income'` |
| `categories` | Categorías personalizadas con `key`, `label`, `color_value`, `icon_codepoint` |
| `budgets` | Límite mensual por `category_key` |
| `recurring_expenses` | Plantillas de gastos/ingresos recurrentes con `day_of_month` |
| `saving_goals` | Metas de ahorro con `target_amount` y `saved_amount` |
| `shared_debts` | Deudas compartidas activas |
| `shared_debt_payments` | Pagos mensuales por deuda (unique por `debt_id + year + month`) |
| `expense_splits` | División de un gasto entre personas (FK a `expenses`) |
| `settings` | Pares `key/value` para configuración (ej. `pay_period_day`) |

### Versión actual: v11

Las migraciones son acumulativas en `DatabaseService._onUpgrade`. Al actualizar la app, cada versión aplica solo su `ALTER TABLE` o `CREATE TABLE` correspondiente sin tocar los datos existentes.

---

## Decisiones de diseño

**¿Por qué SQLite y no una solución en la nube?**
Los datos financieros son sensibles. Toda la información se guarda localmente en el dispositivo. La sincronización con Gmail es de solo lectura y usa el token OAuth del usuario, que nunca pasa por ningún servidor propio.

**¿Por qué Riverpod y no Bloc/Provider?**
Riverpod 2.x permite definir el árbol de dependencias de forma declarativa, con `StreamProvider` que se reconstruye reactivamente cuando cambia la DB. La combinación `StreamProvider` + repositorio con `StreamController.broadcast()` elimina la necesidad de llamadas explícitas a `notifyListeners()` o `emit()`.

**¿Por qué GoRouter con ShellRoute?**
El `ShellRoute` permite mantener la barra de navegación inferior y el FAB persistentes entre pestañas sin re-crear el scaffold en cada navegación. El FAB se oculta condicionalmente según la ruta activa y el estado de la UI (búsqueda activa, sheet de categoría abierto).

**¿Por qué feature-first y no layer-first?**
Con layer-first (`models/`, `repositories/`, `screens/`) toda la lógica relacionada a, por ejemplo, "metas de ahorro" queda esparcida por el árbol. Con feature-first cada feature es autónoma y se puede entender, modificar o eliminar sin tocar otras carpetas.

**Período de pago (fecha de corte)**
El período "26 jun – 25 jul" es la forma en que muchos colombianos gestionan su presupuesto: el salario entra el 26 y ese dinero "pertenece" al mes siguiente. `PeriodUtils` abstrae este cálculo; `Dart` maneja `DateTime(year, 0, day)` como diciembre del año anterior, lo que hace el cálculo correcto para enero sin casos especiales.

**Secretos fuera del repositorio**
Las credenciales OAuth nunca tocan el historial de git. El script `setup_secrets.sh` genera los archivos necesarios a partir de `secrets.env` (git-ignorado). Para `ios/Runner/Info.plist`, que contiene otra configuración importante además del URL scheme, se usa `git update-index --skip-worktree` para que git ignore los cambios locales sin eliminar el archivo del repositorio.
