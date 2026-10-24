# NexoFin AI - Especificación de Requisitos de Software (SRS v2.0)

### Página 1

Datos del proyecto

         Nombre del proyecto                                 NexoFin AI

         Documento                                           Especificación de Requisitos de Software (SRS)

         Asignatura                                          Programación III

         Profesor(a)                                            Eduandy Isabel Cruz Abreu

         Institución                                         Instituto Tecnológico de las Américas (ITLA)

         Fecha                                               Septiembre de 2026


         Integrantes del equipo                                                                                                                        Matrícula

         Paola Piantini                                                                                                                                                 2025-1222

         Brailin Mendez                                                                                                                                  2024-1281

         Romel Augusto Rojas                                                                                                                            2025-1022










                                                                                                                                                                                                                      1

---

### Página 2

Contenido



        1. Introducción y descripción del problema........................................................................................................................                                                                            4

                1.1 Propósito del documento.....................................................................................................................................................................                                       4

                1.2 Descripción del problema.....................................................................................................................................................................4

                1.3 Solución propuesta...............................................................................................................................................................................                                  4

                1.4 Límite de responsabilidad del producto................................................................................................................................................5

                1.5 Definiciones, acrónimos y abreviaturas................................................................................................................................................                                             5

                1.6 Convenciones del documento...............................................................................................................................................................5

                1.7 Organización del documento................................................................................................................................................................6

        2. Objetivos del proyecto....................................................................................................................................................6

                2.1 Objetivo general....................................................................................................................................................................................6

                2.2 Objetivos específicos............................................................................................................................................................................                                  7

        3. Requerimientos funcionales...........................................................................................................................................                                                                      7

                3.1 Resumen de funciones principales.......................................................................................................................................................                                            7

                3.2 Cuenta de usuario y autenticación (AUT)..............................................................................................................................................8

                3.3 Cuentas, tarjetas y deudas (CTA)...........................................................................................................................................................9

                3.4 Registro de transacciones (TRX)..........................................................................................................................................................10

                3.5 Importación y procesamiento documental (IMP)...............................................................................................................................10

                3.6 Categorización de transacciones (CAT)...............................................................................................................................................                                             11

                3.7 Presupuestos y metas (PRE)................................................................................................................................................................12

                3.8 Motor de simulación financiera (SIM)................................................................................................................................................                                             12

                3.9 Asistente conversacional (ASI)............................................................................................................................................................13

                3.10 Notificaciones y alertas (NOT)...........................................................................................................................................................14

                3.11 Dashboard y reportes (DAS)..............................................................................................................................................................14

                3.12 Auditoría y preferencias (AUD).........................................................................................................................................................14

        4. Requerimientos no funcionales.....................................................................................................................................15

                4.1 Seguridad (SEG)...................................................................................................................................................................................15

                4.2 Privacidad y cumplimiento (PRI).........................................................................................................................................................16

                4.3 Inteligencia artificial y explicabilidad (IA)............................................................................................................................................16

                4.4 Rendimiento y escalabilidad (REN).....................................................................................................................................................17

                4.5 Confiabilidad, integridad y recuperación (CON).................................................................................................................................                                                  18

                                                                                                                                                                                                                                                               2

---

### Página 3

4.6 Calidad de datos y precisión monetaria (DAT)....................................................................................................................................18


                4.7 Usabilidad, accesibilidad y compatibilidad (USA)...............................................................................................................................                                                       19

                4.8 Mantenibilidad, pruebas y observabilidad (MNT)..............................................................................................................................                                                          19

        5. Alcance y limitaciones del sistema................................................................................................................................20

                5.1 Alcance................................................................................................................................................................................................20

                5.2 Fuera del alcance................................................................................................................................................................................21

                5.3 Limitaciones y restricciones................................................................................................................................................................22

                5.4 Supuestos y dependencias..................................................................................................................................................................22

                5.5 Riesgos y mitigación............................................................................................................................................................................22

        6. Diagrama de casos de uso.............................................................................................................................................23

                6.1 Actores................................................................................................................................................................................................23

                6.2 Diagrama general de casos de uso......................................................................................................................................................24

                6.3 Catálogo de casos de uso por módulo................................................................................................................................................25

                6.4 Especificación de los casos de uso críticos..........................................................................................................................................28

        Anexo A. Glosario y definiciones de trabajo......................................................................................................................33

        Anexo B. Reglas de negocio..............................................................................................................................................                                                                          34

                B.1 Datos y precisión.................................................................................................................................................................................34

                B.2 Cuentas...............................................................................................................................................................................................34

                B.3 Transacciones......................................................................................................................................................................................35

                B.4 Deudas................................................................................................................................................................................................35

                B.5 Categorización.....................................................................................................................................................................................35

                B.6 Presupuestos y metas.........................................................................................................................................................................36

                B.7 Simulación...........................................................................................................................................................................................36

                B.8 Asistente.............................................................................................................................................................................................37

                B.9 Importación........................................................................................................................................................................................                                   37

                B.10 Seguridad..........................................................................................................................................................................................37










                                                                                                                                                                                                                                                                     3

---

### Página 4

1. Introducción y descripción del problema

     1.1 Propósito del documento
     Este documento es la Especificación de Requisitos de Software (SRS) de NexoFin AI. Describe el problema que el sistema
     resuelve, sus objetivos, lo que debe hacer (requerimientos funcionales), la calidad que debe alcanzar (requerimientos no
     funcionales),    el  alcance   y  las limitaciones    del   proyecto    y  sus  casos   de  uso.   Sirve  como    acuerdo     entre  el equipo de
     desarrollo y quien evalúa el proyecto, y como base para el diseño, la implementación y las pruebas.

     La estructura sigue, de forma adaptada, IEEE Std 830-1998 e ISO/IEC 29148:2018. El documento no contempla decisiones
     de arquitectura ni de tecnología; esas decisiones se documentarán aparte, respetando las restricciones de la sección 5.3.


     1.2 Descripción del problema
     La  administración     del dinero personal suele estar fragmentada entre                aplicaciones    bancarias,    hojas de cálculo,     recibos,
     notas del teléfono y la memoria. Una persona puede conocer su saldo actual y, aun así, no saber cuánto puede gastar sin
     afectar sus cuotas, sus metas         de  ahorro    o  su flujo de efectivo del mes. La diferencia entre registrar lo que ya ocurrió y
     anticipar lo que podría ocurrir es el vacío que este proyecto busca cubrir.

     Muchas herramientas de finanzas personales se concentran en mostrar historiales y gráficos posteriores al gasto. Para el
     usuario común, el reto real aparece antes de decidir: saber si puede asumir un gasto, cómo afectará sus compromisos y
     qué   tendría   que cambiar     para mantener sus        objetivos. Esa     evaluación se hace de forma intuitiva, sin integrar todas las
     variables. Las consecuencias más frecuentes son:

      •   Decisiones de gasto tomadas sin conocer su efecto sobre las cuotas, el presupuesto y las metas.
      •   Registro manual tedioso que se abandona a las pocas semanas.
      •   Movimientos dispersos en varias cuentas, tarjetas y efectivo, sin una vista única.
      •   Dificultad para saber cuánto ahorrar cada mes para alcanzar un objetivo con fecha.
      •   Poca comprensión de la propia situación financiera por falta de explicaciones claras.

     Las personas     afectadas son adultos que manejan su dinero personal,                   con ingresos    regulares o irregulares, que desean
     controlarlo mejor pero no tienen formación contable.


     1.3 Solución propuesta
     NexoFin AI es una plataforma web de finanzas personales que centraliza la información económica del usuario, interpreta
     movimientos      de   distintas  fuentes    y  los convierte en una visión        comprensible de su situación          financiera. Su    elemento
     diferenciador     es  un   asistente   conversacional     conectado     a  un   motor    de  simulación     financiera:   además     de  preguntas
     descriptivas    (“¿cuánto     gasté   este  mes?”),    el  usuario    puede    plantear    escenarios    hipotéticos    (“¿qué    pasaría   si gasto
     RD$20,000 en un resort este mes?” o “¿cuánto debería ahorrar cada mes para comprar una laptop en diciembre?”).

      •   Convertir movimientos dispersos en una única vista financiera personal.
      •   Reducir el trabajo manual mediante importación y clasificación automática de transacciones.
      •   Permitir análisis preventivo mediante simulaciones “what-if” antes de una compra o de asumir una obligación.
      •   Traducir datos financieros a explicaciones claras y accionables.




                                                                                                                                                                4

---

### Página 5

1.4 Límite de responsabilidad del producto
     NexoFin AI es una herramienta de organización, análisis y simulación de finanzas personales. Las respuestas del asistente
     distinguen     entre cálculos basados en los datos del usuario, estimaciones y contenido educativo. El sistema no presenta
     una    simulación     como     garantía    de   resultados     futuros    ni  sustituye    la  asesoría    profesional regulada cuando la decisión
     requiera una evaluación especializada.


     1.5 Definiciones, acrónimos y abreviaturas
     Los   términos     del   dominio     (saldo    libre  proyectado,      escenario,     huella   de   transacción,      etc.)  se  definen     en  el  Anexo    A.
     Acrónimos usados en el documento:

        Acrónimo                    Significado

        SRS                         Especificación de Requisitos de Software.

        RF / RNF                    Requerimiento funcional / requerimiento no funcional.

        RN                          Regla de negocio (Anexo B).

        CU                          Caso de uso (sección 6).

        IA                          Inteligencia artificial.

        2FA                         Autenticación en dos pasos.

        CSV                         Archivo de valores separados por comas, formato común de los estados de cuenta descargables.

        API                         Interfaz mediante la cual la aplicación cliente se comunica con el servidor.

        RPO / RTO                   Pérdida máxima de datos aceptable / tiempo máximo de recuperación tras una falla.

        WCAG                        Pautas de accesibilidad para el contenido web (Web Content Accessibility Guidelines).

        N1 / N2 / N3                Niveles de entrega propuestos (sección 5.1.2).


     1.6 Convenciones del documento
     Cada requisito tiene un identificador único con el formato RF-MÓD-nn (funcional) o RNF-ÁREA-nn (no funcional), donde
     MÓD y ÁREA son el código del módulo o del área de calidad. Cada requisito incluye un criterio verificable de aceptación.
     Los valores numéricos son propuestos y pueden ajustarse tras pruebas de carga o validación con usuarios, pero deben
     conservar el principio de ser medibles.


        Prioridad             Significado

        Crítica               Sin este requisito el producto no puede liberarse o se compromete la seguridad o la integridad financiera.

        Alta                  Necesario para entregar el valor principal del producto.

        Media                 Mejora sustancial de la experiencia o de la calidad; puede planificarse después de los requisitos Alta.


                                                                                                                                                                            5

---

### Página 6

Prioridad             Significado

        Baja                  Deseable; su ausencia no afecta el valor principal.

     Además de la prioridad, cada RF indica su nivel de entrega (N1, N2 o N3; ver la sección 5.1.2) y cada RNF indica si aplica a
     la demo o solo a la producción (columna Aplica en). La prioridad mide la importancia del requisito; el nivel mide el orden
     de entrega. En los RF marcados N1/N3, N2/N3, el primer nivel entrega la parte básica y el segundo la completa (por
     ejemplo, en importación: CSV y Excel en N2 y PDF en N3).


     1.7 Organización del documento


        Sección               Contenido

        1                     Introducción y descripción del problema.

        2                     Objetivo general y objetivos específicos.

        3                     Requerimientos funcionales (resumen de funciones y detalle por módulo).

        4                     Requerimientos no funcionales (seguridad, privacidad, IA, rendimiento, confiabilidad, datos, usabilidad y
                              mantenibilidad).

        5                     Alcance y limitaciones: alcance, niveles de entrega, fuera de alcance, restricciones, supuestos y riesgos.

        6                     Diagrama de casos de uso: actores, diagrama general, catálogo y especificación de los casos críticos.

        Anexos                A glosario; B reglas de negocio.

     2. Objetivos del proyecto

     2.1 Objetivo general




























                                                                                                                                                                              6

---

### Página 7

2.2 Objetivos específicos
      Cada objetivo tiene un indicador de logro medible que se verifica con las pruebas de la sección 4 y del Anexo D.

        ID           Objetivo específico                          Indicador de logro                                                              Requisitos

        OE-01        Permitir registrar y consultar               El saldo de toda cuenta es igual a su saldo inicial más la suma                 RF-CTA, RF-TRX,
                     cuentas, deudas y transacciones              de sus movimientos; la verificación automática no reporta                       RNF-CON-05
                     con saldos siempre consistentes.             discrepancias.

        OE-02        Clasificar automáticamente las               Al menos 85 % de aciertos sobre un conjunto de prueba                           RF-CAT, RNF-DAT-03
                     transacciones y permitir                     etiquetado; ninguna corrección se pierde al reprocesar.
                     corregirlas.

        OE-03        Apoyar la planificación con                  El porcentaje consumido de cada presupuesto se actualiza al                     RF-PRE
                     presupuestos mensuales y metas               registrar, editar o eliminar una transacción; cada meta muestra
                     de ahorro.                                   su aporte mensual requerido.

        OE-04        Simular el efecto de una decisión            Las simulaciones de gasto único y de ahorro para una meta                       RF-SIM, RNF-IA-02 a
                     financiera antes de tomarla.                 muestran supuestos y resultados          reproducibles;     con datos           IA-04
                                                                  insuficientes lo declaran.

        OE-05        Ofrecer un asistente                         Interpreta correctamente al menos 90 % de 50 preguntas de                       RF-ASI, RNF-IA-01, IA-08,
                     conversacional confiable en                  referencia; el 100 % de las cifras de sus respuestas proviene del               IA-09
                     español.                                     motor; funciona también en modo básico.

        OE-06        Reducir el trabajo manual                    Un mismo archivo importado dos veces no crea duplicados; el                     RF-IMP, RNF-CON-03
                     mediante la importación de                   usuario revisa y aprueba los movimientos antes de guardarlos.
                     estados de cuenta.

        OE-07        Proteger la información                      Un usuario no accede a datos de otro en el 100 % de las                         RF-AUT, RF-AUD,
                     financiera del usuario.                      pruebas de acceso; las contraseñas nunca son recuperables; las                  RNF-SEG, RNF-PRI
                                                                  acciones sensibles quedan en la bitácora.

        OE-08        Lograr una experiencia clara para            En una prueba con 10 usuarios, al menos 8 registran su primera                  RNF-USA-01
                     un usuario sin formación                     cuenta, un ingreso y un gasto en 5 minutos o menos sin ayuda.
                     financiera.

        OE-09        Cumplir el plazo y el presupuesto            Demo funcional completa del nivel 1 en 12 semanas con costo                     RNF-MNT-02,
                     del proyecto con calidad                     acumulado de RD$0 y cobertura de pruebas del motor                              RNF-MNT-05
                     verificable.                                 financiero de al menos 80 %.


      3. Requerimientos funcionales

      Los requerimientos funcionales describen lo que el sistema debe hacer. Primero se resumen las funciones principales y
      después se detalla cada requisito por módulo, con su criterio de aceptación, su prioridad y su nivel de entrega. El motor
      de simulación (3.8) y el asistente conversacional (3.9) son el núcleo diferenciador del producto.


      3.1 Resumen de funciones principales


        #         Función                                     Descripción                                                                           Requisitos

        F1        Registro y acceso seguro                    Crear cuenta, iniciar y cerrar sesión, recuperar la contraseña y                      AUT-01, 03, 04, 05, 08
                                                              gestionar el perfil.

        F2        Gestión de cuentas financieras              Registrar cuentas de efectivo, bancarias y tarjetas, y consultar sus                  CTA-01, 03, 05
                                                              saldos.




                                                                                                                                                                                       7

---

### Página 8

#          Función                                        Descripción                                                                               Requisitos

        F3         Gestión de deudas                              Registrar deudas con su calendario de cuotas, sus pagos y su                              CTA-06, 07, 08
                                                                  estado.

        F4         Registro de transacciones                      Registrar ingresos, gastos, transferencias y ajustes; editarlos,                          TRX-01 a 05
                                                                  eliminarlos y buscarlos.

        F5         Transacciones recurrentes                      Definir renta, nómina y suscripciones que se generan solas cada                           TRX-06
                                                                  periodo.

        F6         Importación de estados de                      Cargar archivos CSV o Excel, detectar duplicados y revisar antes de                       IMP-01 a 07
                   cuenta                                         guardar.

        F7         Categorización automática                      Asignar categorías a las transacciones, corregirlas y definir reglas                      CAT-01 a 06
                                                                  propias.

        F8         Presupuestos                                   Definir un presupuesto mensual por categoría y ver cuánto se ha                           PRE-01, 02
                                                                  consumido.

        F9         Metas de ahorro                                Crear metas con monto y fecha, registrar aportes y ver el progreso.                       PRE-03, 04, 05

        F10        Simulación de decisiones                       Simular un gasto hipotético, el ahorro para una meta o una compra                         SIM-01 a 08
                                                                  a cuotas, con alternativas y comparación.

        F11        Asistente conversacional                       Hacer preguntas en lenguaje natural sobre los datos o sobre                               ASI-01 a 08
                                                                  escenarios, con respuestas de cifras trazables.

        F12        Dashboard y reportes                           Ver balance, posición financiera, distribución del gasto y                                DAS-01 a 04
                                                                  tendencias.

        F13        Notificaciones y alertas                       Recibir avisos de presupuesto, vencimientos, importaciones y                              NOT-01 a 03
                                                                  metas.

        F14        Auditoría y actividad de seguridad             Registrar acciones sensibles y consultar la actividad reciente de la                      AUD-01, 02
                                                                  cuenta.

        F15        Portabilidad y baja de datos                   Exportar reportes y datos propios, y eliminar la cuenta.                                  DAS-05, AUT-09, 10

      3.2 Cuenta de usuario y autenticación (AUT)


        ID                  Requisito                                                Criterio de aceptación                                                Prioridad          Nivel

        RF-AUT-01           El sistema permitirá a un usuario nuevo                  El correo se valida en formato y unicidad; la                         Alta               N1
                            registrarse con nombre, correo                           contraseña cumple la política de complejidad
                            electrónico y contraseña.                                definida (longitud mínima de 10 caracteres y no
                                                                                     figurar en una lista de contraseñas comunes).

        RF-AUT-02           El sistema exigirá verificar el correo                   El enlace de verificación es de un solo uso y expira                  Alta               N3
                            electrónico antes de habilitar las                       en 24 horas; sin verificación la cuenta no puede
                            funciones financieras.                                   registrar datos financieros.

        RF-AUT-03           El sistema permitirá iniciar sesión con                  Credenciales inválidas muestran un error genérico                     Crítica            N1
                            correo y contraseña.                                     que no indica cuál campo falló; tras 5 intentos
                                                                                     fallidos consecutivos la cuenta se bloquea
                                                                                     temporalmente 15 minutos (valores configurables).

        RF-AUT-04           El sistema permitirá cerrar sesión de                    El token o la sesión activa queda invalidado tras el                  Media              N1
                            forma explícita.                                         cierre y no puede reutilizarse.





                                                                                                                                                                                                 8

---

### Página 9

ID                  Requisito                                                Criterio de aceptación                                                Prioridad         Nivel

        RF-AUT-05           El sistema permitirá recuperar el acceso                 El enlace expira en 30 minutos como máximo y es                       Alta              N1
                            mediante restablecimiento de contraseña                  de un solo uso; al restablecer, todas las sesiones
                            por correo.                                              activas se invalidan.

        RF-AUT-06           El usuario podrá cambiar su contraseña                   El cambio exige la contraseña actual                                  Media             N3
                            desde su perfil.                                         (reautenticación); las demás sesiones se invalidan y
                                                                                     el usuario recibe un aviso por correo.

        RF-AUT-07           El usuario podrá activar la autenticación                Con la opción activa, el inicio de sesión exige un                    Media             N3
                            en dos pasos.                                            segundo factor; desactivarla exige reautenticación.

        RF-AUT-08           El usuario podrá configurar su perfil                    Los cambios se reflejan de inmediato en la sesión                     Media             N1
                            (nombre, moneda predeterminada, foto).                   activa.

        RF-AUT-09           El usuario podrá eliminar su cuenta y                    La acción exige reautenticación y confirmación                        Media             N3
                            solicitar la baja de sus datos.                          explícita; los datos financieros se eliminan en un
                                                                                     máximo de 30 días y queda un registro de auditoría
                                                                                     sin datos personales.

        RF-AUT-10           El usuario podrá descargar una copia de                  El archivo (CSV o JSON) contiene cuentas,                             Media             N3
                            todos sus datos en un formato                            transacciones, categorías, presupuestos, metas y
                            estructurado.                                            deudas del usuario, y ningún dato de otros usuarios.

      3.3 Cuentas, tarjetas y deudas (CTA)


        ID                  Requisito                                                 Criterio de aceptación                                               Prioridad          Nivel

        RF-CTA-01           El usuario podrá registrar cuentas                        Cada cuenta queda asociada de forma exclusiva al                     Alta               N1
                            financieras (efectivo, cuenta bancaria,                   usuario que la creó y no puede consultarla ningún
                            tarjeta de crédito) con saldo inicial y                   otro usuario. En el nivel 1 todas las cuentas operan
                            moneda.                                                   en una sola moneda (RD$).

        RF-CTA-02           Para las tarjetas de crédito, el usuario                  El sistema muestra saldo utilizado, crédito                          Media              N3
                            podrá registrar límite, fecha de corte y                  disponible y fecha del próximo pago de cada tarjeta.
                            fecha de pago.

        RF-CTA-03           El usuario podrá editar los datos de una                  Si cambia el saldo inicial, los saldos de la cuenta se               Media              N2
                            cuenta financiera.                                        recalculan y el cambio queda en la bitácora.

        RF-CTA-04           El usuario podrá archivar una cuenta                      Una cuenta archivada no admite movimientos                           Media              N3
                            financiera.                                               nuevos ni aparece en los listados activos, pero sus
                                                                                      movimientos se conservan en el historial y los
                                                                                      reportes. Solo puede eliminarse definitivamente
                                                                                      una cuenta sin movimientos.

        RF-CTA-05           El usuario podrá consultar el saldo de                    El total por moneda coincide con la suma de los                      Alta               N1
                            cada cuenta y el total por moneda.                        saldos de sus cuentas activas.

        RF-CTA-06           El usuario podrá registrar deudas u                       El sistema genera el calendario de cuotas y calcula                  Alta               N1
                            obligaciones (acreedor, monto original,                   el saldo pendiente inicial.
                            tasa, número de cuotas, fecha de la
                            primera cuota).

        RF-CTA-07           El usuario podrá registrar un pago de                     El pago genera un gasto asociado en la cuenta                        Alta               N1
                            deuda indicando monto, fecha y cuenta                     elegida y el saldo pendiente de la deuda se
                            de origen.                                                recalcula tras cada pago, de forma atómica.





                                                                                                                                                                                                9

---

### Página 10

ID                 Requisito                                                Criterio de aceptación                                                Prioridad        Nivel

        RF-CTA-08          El usuario podrá consultar el estado de                  Por cada obligación se muestra próxima cuota                          Media            N1
                           sus deudas.                                              (fecha y monto), cuotas restantes y monto
                                                                                    pendiente.

        RF-CTA-09          El sistema mostrará un calendario de                     Muestra en orden cronológico, para los próximos                       Media            N3
                           obligaciones.                                            60 días, las cuotas de deuda, los pagos de tarjeta y
                                                                                    las transacciones recurrentes de gasto.

        RF-CTA-10          Cuando una transacción esté en una                       Los reportes consolidados convierten a la moneda                      Media            N3
                           moneda distinta a la predeterminada, el                  predeterminada y muestran la tasa aplicada a cada
                           sistema registrará la tasa de cambio                     conversión.
                           utilizada.

      3.4 Registro de transacciones (TRX)


        ID                  Requisito                                                Criterio de aceptación                                               Prioridad        Nivel

        RF-TRX-01           El usuario podrá registrar manualmente                   El monto se ingresa en positivo y el tipo define su                  Crítica          N1
                            una transacción de tipo ingreso, gasto,                  efecto; el sistema rechaza montos iguales o
                            transferencia o ajuste, con monto, fecha,                menores que cero, fechas inválidas y campos
                            cuenta, categoría y nota.                                obligatorios vacíos. Las transferencias no requieren
                                                                                     categoría.

        RF-TRX-02           El usuario podrá registrar transferencias                Se crean una salida y una entrada vinculadas en una                  Alta             N1
                            entre sus cuentas.                                       sola operación atómica; la transferencia no cuenta
                                                                                     como ingreso ni como gasto en balances y
                                                                                     presupuestos.

        RF-TRX-03           El usuario podrá editar una transacción                  El saldo de las cuentas afectadas se recalcula y el                  Alta             N1
                            existente.                                               valor anterior queda en el historial de cambios de la
                                                                                     transacción.

        RF-TRX-04           El usuario podrá eliminar una transacción.               La eliminación exige confirmación, es una baja                       Alta             N1
                                                                                     lógica, recalcula los saldos afectados y queda en la
                                                                                     bitácora.

        RF-TRX-05           El usuario podrá consultar el historial de               Los resultados coinciden exactamente con los filtros                 Alta             N1
                            transacciones con filtros por fecha,                     seleccionados y se presentan paginados.
                            cuenta, categoría, monto y texto.

        RF-TRX-06           El usuario podrá registrar transacciones                 El sistema genera la transacción en cada periodo; el                 Alta             N1
                            recurrentes (renta, suscripciones, nómina)               usuario puede pausar, editar o finalizar la
                            con frecuencia, fecha de inicio y fecha de               recurrencia sin alterar las ya generadas. Las
                            fin opcional.                                            recurrentes de ingreso y gasto alimentan las
                                                                                     proyecciones.

      3.5 Importación y procesamiento documental (IMP)


        ID                 Requisito                                                Criterio de aceptación                                                Prioridad        Nivel

        RF-IMP-01          El usuario podrá subir un estado de                      Archivos corruptos, de formato no soportado o que                     Alta             N2/N3
                           cuenta en CSV, Excel (XLS o XLSX) o PDF.                 superen el tamaño máximo configurado son
                                                                                    rechazados con un mensaje claro, sin afectar el
                                                                                    resto de la sesión. Los formatos CSV y Excel se
                                                                                    admiten en el nivel 2 y el PDF en el nivel 3.




                                                                                                                                                                                            10

---

### Página 11

ID                 Requisito                                                 Criterio de aceptación                                               Prioridad         Nivel

        RF-IMP-02          Para archivos CSV o Excel con columnas                    El mapeo elegido se aplica a todo el archivo y puede                 Media             N2
                           no reconocidas, el usuario podrá indicar                  guardarse para futuras importaciones del mismo
                           qué columna corresponde a fecha, monto                    formato.
                           y descripción.

        RF-IMP-03          El sistema extraerá de cada estado de                     Al menos 90 % de los movimientos de un conjunto                      Alta              N2/N3
                           cuenta la fecha, el monto, la descripción y               de estados de prueba definido en el plan de
                           el sentido (débito o crédito) de cada                     pruebas (mínimo 10 estados de 3 emisores
                           movimiento.                                               distintos) se extrae correctamente sin intervención
                                                                                     manual; en el nivel 2 el conjunto incluye solo
                                                                                     archivos CSV y Excel.

        RF-IMP-04          El usuario podrá consultar el estado de                   El estado es uno de: en cola, procesando, lista para                 Alta              N3
                           una importación en curso.                                 revisión, fallida o confirmada; una importación
                                                                                     fallida indica el motivo.

        RF-IMP-05          El sistema detectará posibles duplicados                  La huella de comparación incluye cuenta, fecha,                      Alta              N2
                           entre los movimientos importados y las                    monto y descripción normalizada; importar dos
                           transacciones ya registradas.                             veces el mismo archivo no crea registros duplicados
                                                                                     silenciosos.

        RF-IMP-06          El usuario podrá revisar un resumen de los                El resumen muestra movimientos detectados,                           Alta              N2
                           movimientos detectados antes de                           duplicados potenciales y registros a corregir; el
                           confirmar la importación.                                 usuario puede editar, excluir o aprobar cada
                                                                                     movimiento antes de que se guarde.

        RF-IMP-07          Al confirmar una importación, el sistema                  Ante un fallo durante el guardado no queda ningún                    Alta              N2
                           guardará todos los movimientos                            movimiento parcial y el usuario es informado.
                           aprobados o ninguno.

        RF-IMP-08          El usuario podrá deshacer una                             Dentro de los 30 días siguientes, todos los                          Media             N3
                           importación ya confirmada.                                movimientos de esa importación pasan a baja lógica
                                                                                     y los saldos se recalculan.

      3.6 Categorización de transacciones (CAT)


        ID                 Requisito                                                 Criterio de aceptación                                               Prioridad         Nivel

        RF-CAT-01          El sistema asignará automáticamente una                   La asignación se basa en la descripción, el comercio,                Alta              N1
                           categoría a cada transacción registrada o                 las reglas del usuario (cuando existan) y sus
                           importada.                                                correcciones previas. Si ninguna coincide, la
                                                                                     transacción queda como “Sin categoría” y no se le
                                                                                     asigna una categoría por suposición.

        RF-CAT-02          El usuario podrá crear reglas de                          Las reglas del usuario tienen precedencia sobre la                   Media             N2
                           categorización (por ejemplo, si la                        clasificación automática y pueden editarse o
                           descripción contiene un texto, asignar una                eliminarse.
                           categoría).

        RF-CAT-03          El usuario podrá corregir manualmente la                  La corrección se conserva en reprocesamientos                        Alta              N1
                           categoría de cualquier transacción.                       posteriores; cuando existan reglas de
                                                                                     categorización (RF-CAT-02), el sistema ofrece crear
                                                                                     una regla a partir de ella.

        RF-CAT-04          El usuario podrá crear, editar y archivar                 Antes de eliminar una categoría con transacciones,                   Media             N3
                           categorías personalizadas.                                el sistema exige reasignarlas a otra o archivarla;
                                                                                     ninguna transacción queda sin categoría.



                                                                                                                                                                                             11

---

### Página 12

ID                 Requisito                                                Criterio de aceptación                                               Prioridad        Nivel

        RF-CAT-05          El sistema proporcionará un conjunto                     Las categorías iniciales están disponibles desde el                  Media            N1
                           inicial de categorías de gasto e ingreso.                primer acceso y no pueden eliminarse.

        RF-CAT-06          El sistema marcará como pendiente de                     Con confianza menor al umbral configurado la                         Media            N2
                           revisión toda transacción cuya confianza                 transacción no recibe categoría silenciosamente y
                           de clasificación sea baja.                               aparece en una bandeja de revisión.

      3.7 Presupuestos y metas (PRE)


        ID                 Requisito                                                Criterio de aceptación                                              Prioridad         Nivel

        RF-PRE-01          El usuario podrá definir un presupuesto                  El sistema muestra el porcentaje consumido,                         Alta              N1
                           mensual por categoría.                                   calculado con las transacciones del mes, y lo
                                                                                    actualiza al registrar, editar o eliminar una
                                                                                    transacción.

        RF-PRE-02          El sistema alertará cuando una categoría                 Se generan alertas al llegar al umbral configurado                  Media             N2
                           alcance un umbral de su presupuesto o lo                 (80 % por defecto) y al superar el 100 %, en el
                           supere.                                                  momento en que se registra la transacción que las
                                                                                    provoca.

        RF-PRE-03          El usuario podrá crear una meta de ahorro                El sistema calcula el monto mensual necesario                       Media             N1
                           con monto objetivo, fecha límite y cuenta                como (objetivo menos acumulado) dividido entre
                           opcional.                                                los meses restantes.

        RF-PRE-04          El usuario podrá registrar aportes a una                 El aporte incrementa el acumulado de la meta y                      Media             N1
                           meta de ahorro indicando monto, fecha y                  queda vinculado a una transacción de la cuenta de
                           cuenta de origen.                                        origen.

        RF-PRE-05          El usuario podrá consultar el progreso de                La vista muestra monto acumulado, monto                             Media             N1
                           cada meta.                                               objetivo, porcentaje de avance y fecha estimada de
                                                                                    cumplimiento al ritmo actual de aportes.

        RF-PRE-06          El usuario podrá editar, pausar o cerrar                 Una meta pausada o cerrada deja de contar como                      Baja              N3
                           una meta de ahorro.                                      compromiso en las simulaciones.

      3.8 Motor de simulación financiera (SIM)


        ID                 Requisito                                                Criterio de aceptación                                              Prioridad         Nivel

        RF-SIM-01          El usuario podrá simular un gasto                        El resultado muestra el saldo libre proyectado antes                Crítica           N1
                           hipotético indicando monto, categoría,                   y después, el efecto en el presupuesto de la
                           fecha aproximada y horizonte (por                        categoría, en las metas activas y en las obligaciones
                           defecto, fin del mes en curso; hasta 12                  próximas. Cada simulación queda registrada
                           meses).                                                  internamente con la copia de los datos usados y su
                                                                                    resultado.

        RF-SIM-02          El usuario podrá simular cuánto debería                  El cálculo usa los ingresos esperados, los gastos fijos             Alta              N1
                           ahorrar mensualmente para alcanzar una                   y el saldo disponible registrados, e indica si el
                           meta en una fecha dada.                                  ahorro requerido es viable.

        RF-SIM-03          El usuario podrá simular una compra a                    El resultado muestra cuota mensual, costo total,                    Alta              N2
                           cuotas o un financiamiento indicando                     intereses pagados y efecto en el flujo mensual
                           monto, tasa y número de cuotas.                          durante todo el plazo.





                                                                                                                                                                                           12

---

### Página 13

ID                  Requisito                                                 Criterio de aceptación                                                Prioridad         Nivel

        RF-SIM-04           Cuando un escenario deje el saldo libre                   Se ofrece al menos una alternativa calculada                          Alta              N2
                            proyectado en negativo, supere un                         (recortar una categoría, posponer el gasto o
                            presupuesto o comprometa una meta, el                     redistribuir el mes) con el efecto numérico de cada
                            sistema propondrá alternativas.                           una.

        RF-SIM-05           El sistema mostrará los supuestos y                       El usuario puede identificar qué ingresos, gastos,                    Alta              N1
                            variables utilizados en cada simulación.                  saldos, periodo y parámetros se usaron para el
                                                                                      resultado.

        RF-SIM-06           El sistema indicará cuando los datos sean                 Con datos insuficientes (según el glosario) el                        Alta              N1
                            insuficientes para simular con confianza.                 resultado explica qué falta y no presenta una cifra
                                                                                      como exacta.

        RF-SIM-07           El usuario podrá guardar y consultar el                   Una simulación guardada se reabre con el mismo                        Media             N2
                            historial de simulaciones.                                resultado original aunque los datos hayan
                                                                                      cambiado, y ofrece recalcular con los datos
                                                                                      actuales.

        RF-SIM-08           El usuario podrá comparar hasta tres                      La comparación muestra, para cada escenario,                          Media             N3
                            escenarios lado a lado.                                   saldo libre proyectado, efecto en presupuestos y
                                                                                      efecto en metas.

      3.9 Asistente conversacional (ASI)


        ID                  Requisito                                                 Criterio de aceptación                                                Prioridad         Nivel

        RF-ASI-01           El usuario podrá formular preguntas en                    El asistente identifica la intención y los parámetros                 Crítica           N1
                            lenguaje natural sobre su situación                       de la pregunta; la calidad se mide con el conjunto
                            financiera o sobre escenarios hipotéticos.                de referencia de RNF-IA-08.

        RF-ASI-02           El asistente responderá con una                           Ninguna cifra de la respuesta carece de origen en                     Crítica           N1
                            explicación basada en resultados                          un dato persistido o en un cálculo del motor, y el
                            calculados por el motor financiero.                       usuario puede abrir el detalle del cálculo.

        RF-ASI-03           Cuando falte un dato necesario (monto,                    El asistente no asume valores no indicados por el                     Alta              N1
                            fecha, categoría), el asistente lo solicitará             usuario; pregunta por cada dato faltante y luego
                            antes de simular.                                         ejecuta la simulación.

        RF-ASI-04           El asistente indicará cuando no cuente                    Ante datos insuficientes lo declara en vez de                         Alta              N1
                            con información suficiente para simular                   presentar una cifra estimada como exacta.
                            con confianza.

        RF-ASI-05           Cada respuesta indicará si su contenido es                Toda respuesta con cifras lleva la etiqueta                           Alta              N1
                            un cálculo con datos del usuario, una                     correspondiente; las simulaciones incluyen el aviso
                            estimación o contenido educativo.                         de que no garantizan resultados futuros ni
                                                                                      sustituyen asesoría profesional regulada.

        RF-ASI-06           El asistente no creará, modificará ni                     Toda acción que cambie datos muestra un resumen                       Alta              N2
                            eliminará datos financieros sin                           y requiere una confirmación antes de ejecutarse;
                            confirmación explícita del usuario.                       por defecto el asistente solo consulta.

        RF-ASI-07           El asistente rechazará con un mensaje                     Ante una consulta fuera de ámbito responde que no                     Media             N1
                            informativo las consultas ajenas a las                    puede atenderla y no ejecuta operaciones sobre los
                            finanzas personales del usuario.                          datos.

        RF-ASI-08           El asistente mantendrá el contexto de la                  Nivel 1: una pregunta de seguimiento se resuelve                      Media             N1/N3
                            conversación en curso y el usuario podrá                  con el contexto anterior. Nivel 3: el usuario consulta
                            ver y borrar su historial de                              y borra sus conversaciones y, al borrar una, no
                            conversaciones.                                           queda copia accesible para él.


                                                                                                                                                                                               13

---

### Página 14

3.10 Notificaciones y alertas (NOT)


        ID                 Requisito                                                 Criterio de aceptación                                               Prioridad         Nivel

        RF-NOT-01          El sistema notificará dentro de la                        La notificación se genera en el momento del                          Media             N2
                           aplicación los eventos relevantes:                        evento; las de vencimiento se emiten con la
                           presupuesto superado o cerca del límite,                  anticipación configurada (3 días por defecto).
                           cuota o pago de tarjeta próximo,
                           importación lista para revisión y meta
                           alcanzada.

        RF-NOT-02          El usuario podrá elegir qué tipos de                      Una notificación desactivada no se genera ni se                      Media             N3
                           notificación recibir y por qué canal                      envía por el canal desactivado.
                           (aplicación o correo).

        RF-NOT-03          El usuario podrá consultar su historial de                El historial conserva al menos los últimos 90 días de                Baja              N3
                           notificaciones y marcarlas como leídas.                   notificaciones, con su estado de lectura.

      3.11 Dashboard y reportes (DAS)


        ID                 Requisito                                                Criterio de aceptación                                                Prioridad        Nivel

        RF-DAS-01          El sistema mostrará un balance general de                El balance coincide exactamente con la suma de las                    Alta             N1
                           ingresos, gastos y saldo neto del periodo                transacciones del periodo filtrado y excluye las
                           seleccionado.                                            transferencias.

        RF-DAS-02          El sistema mostrará la posición financiera               Cada cifra puede desglosarse en los datos y cálculos                  Alta             N1
                           actual: saldo disponible, deuda total y                  que la componen.
                           saldo libre proyectado al cierre del mes.

        RF-DAS-03          El sistema mostrará la distribución del                  El gráfico se actualiza al registrar, editar o eliminar               Media            N2
                           gasto por categoría en un gráfico.                       una transacción.

        RF-DAS-04          El sistema mostrará la tendencia de                      La comparación cubre, como mínimo, los últimos                        Media            N3
                           ingresos y gastos entre meses.                           seis meses con datos disponibles.

        RF-DAS-05          El usuario podrá exportar un reporte de                  El archivo exportado refleja exactamente los filtros                  Baja             N3
                           transacciones o un resumen del periodo                   aplicados en pantalla.
                           en PDF o Excel.

      3.12 Auditoría y preferencias (AUD)


        ID                 Requisito                                                Criterio de aceptación                                               Prioridad         Nivel

        RF-AUD-01          El sistema registrará en una bitácora las                Cada registro incluye usuario, acción, resultado,                    Alta              N1
                           acciones sensibles: inicio y fallo de inicio             fecha y hora, sin datos sensibles en claro; el usuario
                           de sesión, cambios de seguridad,                         no puede modificar ni eliminar la bitácora.
                           importación, eliminación de datos y
                           exportación.

        RF-AUD-02          El usuario podrá consultar su actividad de               Se muestran al menos los últimos 20 inicios de                       Media             N3
                           seguridad reciente.                                      sesión (fecha, resultado) y los cambios de seguridad
                                                                                    de su cuenta.

        RF-AUD-03          El usuario podrá configurar preferencias                 Las preferencias se aplican por defecto en toda la                   Media             N3
                           predeterminadas (moneda, formato de                      aplicación desde la siguiente carga.
                           fecha, notificaciones).


                                                                                                                                                                                            14

---

### Página 15

4. Requerimientos no funcionales

      Los requerimientos no funcionales establecen cómo debe comportarse el sistema y qué nivel mínimo de calidad debe
      alcanzar. Cada requisito incluye un criterio de verificación medible. La columna Aplica en distingue lo que se verifica en la
      demo (Ambas) de lo que solo es un objetivo de producción.


      4.1 Seguridad (SEG)


        ID                 Requisito                                              Criterio de verificación                                         Prioridad        Aplica en

        RNF-SEG-01         Toda comunicación entre el cliente y los               Ningún punto de acceso responde en canal sin                     Crítica          Ambas
                           servicios del sistema, incluidos los                   cifrar (se redirige o se rechaza); una revisión de
                           servicios externos, viaja cifrada; no se               configuración y un escaneo de puertos lo
                           transmiten credenciales, documentos ni                 confirman antes de cada versión. En la demo se
                           tokens por canales sin cifrar.                         acepta canal sin cifrar solo en localhost.

        RNF-SEG-02         Las contraseñas se almacenan mediante                  La revisión del almacenamiento no revela                         Crítica          Ambas
                           una función de derivación resistente a                 ninguna contraseña ni valor reversible; dos
                           fuerza bruta y con sal individual; nunca               usuarios con la misma contraseña tienen valores
                           en texto plano ni con cifrado reversible.              almacenados distintos.

        RNF-SEG-03         Los datos financieros, los documentos                  Una copia del medio de almacenamiento, sin las                   Alta             Ambas
                           importados y las copias de seguridad se                claves, no permite leer datos financieros; las
                           protegen con cifrado en reposo.                        claves se gestionan separadas de los datos. En la
                                                                                  demo se acepta el cifrado que ofrezca la
                                                                                  plataforma de datos elegida.

        RNF-SEG-04         Las sesiones expiran por inactividad y los             Tras 30 minutos de inactividad (valor                            Alta             Ambas
                           tokens pueden revocarse. Cambiar la                    configurable) la sesión deja de ser válida; un
                           contraseña, desactivar la autenticación                token revocado es rechazado en la siguiente
                           en dos pasos y eliminar la cuenta exigen               solicitud.
                           reautenticación reciente.

        RNF-SEG-05         Cada usuario solo puede consultar,                     En pruebas con identificadores ajenos                            Crítica          Ambas
                           modificar o eliminar sus propios datos                 (manipulación de URL, cuerpo de solicitud o
                           financieros. La autorización se valida                 llamadas directas al API), el 100 % de los intentos
                           siempre en el servidor y no depende de                 es denegado y queda registrado.
                           controles del cliente.

        RNF-SEG-06         El sistema limita la frecuencia de                     Al superar el límite configurado la solicitud se                 Alta             Ambas
                           intentos y solicitudes en las operaciones              rechaza con un mensaje claro; el límite se verifica
                           susceptibles de abuso: inicio de sesión,               con pruebas automatizadas.
                           recuperación de contraseña,
                           importación y asistente.

        RNF-SEG-07         Claves, tokens, cadenas de conexión y                  Un análisis automático del repositorio y de su                   Crítica          Ambas
                           demás secretos no se almacenan en el                   historial no detecta secretos.
                           código fuente ni en el repositorio de
                           control de versiones.

        RNF-SEG-08         Los archivos subidos y los datos de                    Se valida el tipo real del archivo y no solo la                  Alta             Ambas
                           entrada se validan antes de procesarse                 extensión; un conjunto de archivos y entradas
                           para evitar contenido malicioso e                      maliciosas de prueba es rechazado sin afectar al
                           inyección de consultas o instrucciones.                sistema.







                                                                                                                                                                                          15

---

### Página 16

4.2 Privacidad y cumplimiento (PRI)


        ID                  Requisito                                              Criterio de verificación                                          Prioridad         Aplica en

        RNF-PRI-01          Los documentos importados se tratan                    Terminado el procesamiento, el documento                          Alta              Ambas
                            como información sensible y se                         original se elimina en un máximo de 24 horas,
                            conservan solo el tiempo necesario para                salvo autorización expresa del usuario y con un
                            procesarlos o el periodo que el usuario                tope de 30 días (valores configurables).
                            autorice.

        RNF-PRI-02          Al proveedor externo de IA solo se envía               La revisión de las solicitudes salientes en el                    Crítica           Ambas
                            la información estrictamente necesaria                 entorno de pruebas no contiene nombre, correo
                            para la consulta, sin identificadores                  ni números completos de cuenta; la configuración
                            personales directos ni números                         del proveedor excluye el uso de los datos para
                            completos de cuenta, y sin permitir su                 entrenamiento; en la demo con un proveedor
                            uso para entrenar modelos. Si el modelo                externo se usan únicamente datos de prueba.
                            se ejecuta en el propio equipo, ningún
                            dato sale de él.

        RNF-PRI-03          Antes de usar el asistente por primera                 Sin aceptación registrada el asistente no está                    Alta              Ambas
                            vez, el usuario recibe un aviso claro                  disponible; tras la revocación no se envían más
                            sobre qué datos se procesan con                        datos al proveedor.
                            servicios externos y debe aceptarlo;
                            puede revocarlo después. Si el modelo
                            se ejecuta en el propio equipo, este
                            aviso no es necesario.

        RNF-PRI-04          El tratamiento de datos personales                     Existe una lista de verificación de cumplimiento,                 Alta              Producción
                            cumple la Ley 172-13 de protección de                  revisada por asesoría legal antes de la puesta en
                            datos personales de la República                       producción; los derechos de acceso y cancelación
                            Dominicana, incluidos los derechos de                  se ejercen con RF-AUT-09 y RF-AUT-10.
                            acceso, rectificación y cancelación.

        RNF-PRI-05          Los registros técnicos y la bitácora de                Una revisión de muestras de registros no                          Alta              Ambas
                            auditoría no almacenan contraseñas,                    encuentra datos sensibles en claro; los números
                            tokens ni números completos de cuenta.                 de cuenta aparecen enmascarados (solo los
                                                                                   últimos 4 dígitos).

      4.3 Inteligencia artificial y explicabilidad (IA)


        ID                  Requisito                                              Criterio de verificación                                         Prioridad          Aplica en

        RNF-IA-01           Toda respuesta del asistente que incluya               En una batería automatizada de preguntas de                      Crítica            Ambas
                            cifras se origina en datos o resultados                referencia, el 100 % de las cifras coincide con un
                            del motor financiero. La capa de IA no                 dato persistido o un resultado del motor; una
                            inventa saldos, tasas, transacciones ni                respuesta con una cifra sin origen se bloquea o
                            montos ausentes.                                       corrige antes de mostrarse.

        RNF-IA-02           Toda simulación muestra los supuestos                  Cada resultado incluye un bloque de supuestos                    Alta               Ambas
                            relevantes, el periodo analizado y las                 con ingresos, gastos fijos, saldos, periodo y
                            principales variables consideradas, de                 parámetros del escenario.
                            modo que el usuario entienda por qué
                            cambió el resultado.

        RNF-IA-03           Cuando la información es insuficiente o                Con datos insuficientes (según el glosario) el                   Crítica            Ambas
                            contradictoria, el asistente y el motor lo             resultado indica qué falta y no muestra un valor
                            indican y evitan presentar una                         definitivo; se verifica con casos de prueba.
                            conclusión numérica como exacta.




                                                                                                                                                                                            16

---

### Página 17

ID                  Requisito                                              Criterio de verificación                                         Prioridad         Aplica en

        RNF-IA-04           Cada simulación se asocia a la versión de              Al recalcular una simulación con la misma                        Alta              Ambas
                            los datos financieros usada, a los                     versión de datos y los mismos parámetros se
                            parámetros del escenario y al resultado                obtiene exactamente el mismo resultado.
                            calculado, para poder reproducirla en
                            pruebas o soporte.

        RNF-IA-05           El asistente trata como datos, y nunca                 Con al menos 20 textos de prueba con                             Crítica           Ambas
                            como instrucciones, el texto de                        instrucciones incrustadas, ninguno altera el
                            descripciones, notas y documentos                      comportamiento del asistente ni expone datos
                            importados.                                            de otros usuarios.

        RNF-IA-06           El asistente responde en un tiempo                     El 95 % de las respuestas se entrega en menos de                 Media             Ambas
                            razonable y su consumo está acotado.                   8 segundos (valor propuesto); existe un límite
                                                                                   configurable de consultas por usuario y por día, y
                                                                                   al alcanzarlo se informa con claridad.

        RNF-IA-07           Si el servicio de IA no está disponible, el            Con el servicio de IA desconectado, el registro, el              Alta              Ambas
                            resto del sistema sigue funcionando.                   dashboard y la simulación por formulario
                                                                                   funcionan con normalidad y el asistente muestra
                                                                                   un aviso de no disponibilidad.

        RNF-IA-08           La calidad de interpretación del                       Existe un conjunto de al menos 50 preguntas con                  Alta              Ambas
                            asistente se mide con un conjunto de                   la intención y la operación esperadas; el
                            preguntas de referencia.                               asistente las interpreta correctamente en al
                                                                                   menos 90 % de los casos antes de liberar cada
                                                                                   versión.

        RNF-IA-09           El asistente cumple sus requisitos con y               Con el modelo de lenguaje desactivado, las                       Alta              Ambas
                            sin modelo de lenguaje: las consultas y                intenciones de simulación de gasto, ahorro para
                            simulaciones principales se interpretan y              meta y compra a cuotas, y las consultas de gasto
                            responden en un modo básico basado en                  por periodo se resuelven con respuestas basadas
                            reglas y plantillas, y el modelo de                    en plantillas y con todas las cifras provenientes
                            lenguaje, cuando se usa, solo amplía la                del motor; el conjunto de referencia de
                            comprensión de preguntas no previstas.                 RNF-IA-08 se mide por separado en ambos
                                                                                   modos.

      4.4 Rendimiento y escalabilidad (REN)


        ID                  Requisito                                              Criterio de verificación                                         Prioridad         Aplica en

        RNF-REN-01          Las operaciones comunes del API                        El 95 % responde en menos de 800 ms con la                       Alta              Ambas
                            (consultar transacciones, categorías,                  carga de referencia de 200 usuarios concurrentes
                            presupuestos y saldos) responden con                   y cuentas de hasta 50 000 transacciones (valores
                            rapidez bajo la carga de referencia.                   propuestos, ajustables). En la demo: 30 usuarios
                                                                                   concurrentes, medidos en un equipo local.

        RNF-REN-02          El dashboard presenta su contenido                     Menos de 2,5 segundos en una conexión estable,                   Alta              Ambas
                            principal en un tiempo aceptable.                      excluyendo los procesos de importación.

        RNF-REN-03          La importación de estados de cuenta no                 Un estado de 500 movimientos queda listo para                    Alta              Ambas
                            bloquea la aplicación.                                 revisión en menos de 60 segundos; si el proceso
                                                                                   supera el tiempo interactivo (5 s) pasa a segundo
                                                                                   plano con indicador de progreso.







                                                                                                                                                                                            17

---

### Página 18

ID                 Requisito                                             Criterio de verificación                                        Prioridad         Aplica en

        RNF-REN-04         El diseño debe permitir separar el                    La  documentación de arquitectura demuestra los                 Media             Ambas
                           procesamiento documental y la                         límites  entre módulos y una prueba muestra que
                           integración de IA del resto del sistema               el motor financiero opera sin ellos.
                           sin modificar el modelo de datos ni las
                           reglas del dominio financiero.

      4.5 Confiabilidad, integridad y recuperación (CON)


        ID                 Requisito                                             Criterio de verificación                                        Prioridad         Aplica en

        RNF-CON-01         El servicio principal mantiene una                    La disponibilidad se mide con monitoreo                         Alta              Producción
                           disponibilidad mensual mínima de 99,5                 automático y se reporta cada mes.
                           % en producción, excluyendo
                           mantenimientos comunicados con al
                           menos 24 horas de anticipación.

        RNF-CON-02         Las operaciones que implican varios                   Ante un fallo simulado a mitad de la operación                  Crítica           Ambas
                           cambios relacionados (transferencias,                 no queda ningún registro parcial ni saldo
                           pagos de deuda, confirmación de                       inconsistente.
                           importaciones) se ejecutan de forma
                           atómica.

        RNF-CON-03         Reintentar o repetir una importación o                Importar dos veces el mismo archivo no crea                     Alta              Ambas
                           una operación no duplica una                          duplicados; repetir una solicitud con el mismo
                           transacción cuando existe una huella o                identificador de operación produce un único
                           un identificador suficiente para                      efecto.
                           reconocerla.

        RNF-CON-04         Existen copias de seguridad automáticas               RPO máximo de 24 horas y RTO máximo de 4                        Alta              Ambas
                           y un procedimiento documentado de                     horas; la restauración se prueba al menos una
                           restauración.                                         vez antes de la primera puesta en producción y
                                                                                 luego cada trimestre.

        RNF-CON-05         El saldo de toda cuenta es siempre igual              Una verificación automática diaria no reporta                   Crítica           Ambas
                           a su saldo inicial más la suma de sus                 discrepancias; cualquier diferencia genera una
                           movimientos.                                          alerta interna.

      4.6 Calidad de datos y precisión monetaria (DAT)


        ID                 Requisito                                             Criterio de verificación                                        Prioridad        Aplica en

        RNF-DAT-01         El sistema valida formato, signo,                     Los registros inválidos se rechazan o quedan                    Alta             Ambas
                           moneda, fecha y campos obligatorios                   marcados para revisión; se verifica con casos de
                           antes de incorporar una transacción.                  prueba de valores límite.

        RNF-DAT-02         Los importes se almacenan y calculan                  Pruebas unitarias con casos límite (centavos,                   Crítica          Ambas
                           con tipos decimales exactos, asociados a              redondeo, cuotas con intereses) producen
                           una moneda explícita y con una única                  resultados idénticos a valores esperados
                           regla de redondeo documentada; se                     calculados de forma independiente.
                           evita la coma flotante binaria.

        RNF-DAT-03         La categorización automática alcanza                  Al menos 85 % de aciertos sobre un conjunto de                  Media            Ambas
                           una calidad mínima medible.                           transacciones de prueba etiquetadas
                                                                                 manualmente, con el umbral de confianza
                                                                                 vigente.



                                                                                                                                                                                        18

---

### Página 19

ID                 Requisito                                             Criterio de verificación                                        Prioridad         Aplica en

        RNF-DAT-04         Las fechas y los cortes de periodo                    Una transacción registrada a las 23:30 del último               Media             Ambas
                           respetan la zona horaria del usuario                  día del mes se contabiliza en ese mes.
                           (America/Santo_Domingo por defecto).

      4.7 Usabilidad, accesibilidad y compatibilidad (USA)


        ID                 Requisito                                             Criterio de verificación                                        Prioridad        Aplica en

        RNF-USA-01         Un usuario nuevo puede registrar su                   En una prueba con al menos 10 usuarios, 8 o más                 Alta             Ambas
                           primera cuenta, un ingreso y un gasto                 completan la tarea en 5 minutos o menos sin
                           sin consultar documentación externa; la               ayuda.
                           interfaz usa lenguaje financiero sencillo
                           y explica los términos técnicos.

        RNF-USA-02         Las pantallas principales mantienen                   Cumplen el nivel AA de WCAG 2.1 según una lista                 Media            Ambas
                           navegación por teclado, etiquetas                     de  verificación   y  una herramienta automática de
                           comprensibles, contraste suficiente y                 revisión.
                           retroalimentación que no depende solo
                           del color.

        RNF-USA-03         La aplicación es utilizable desde móvil,              Los flujos esenciales se completan sin                          Alta             Ambas
                           tableta y escritorio sin perder las                   desplazamiento horizontal desde un ancho de
                           funciones esenciales de consulta,                     pantalla de 360 px.
                           registro y simulación.

        RNF-USA-04         La versión web funciona en los                        Funciona correctamente en las dos últimas                       Media            Ambas
                           navegadores modernos definidos por el                 versiones estables de Chrome/Chromium y de
                           equipo.                                               Firefox o Edge.

        RNF-USA-05         La interfaz y el asistente se presentan en            Ninguna cadena visible de la interfaz principal                 Media            Ambas
                           español (República Dominicana), con                   queda en otro idioma; importes y fechas se
                           RD$ como moneda predeterminada,                       muestran con el formato indicado.
                           formato de fecha DD/MM/AAAA y
                           separadores numéricos locales.

        RNF-USA-06         Las operaciones que tardan muestran un                Todo flujo asíncrono muestra progreso; ningún                   Media            Ambas
                           estado de carga y los errores se                      mensaje de error visible contiene trazas ni
                           comunican con mensajes comprensibles,                 identificadores internos.
                           sin exponer detalles técnicos.


      4.8 Mantenibilidad, pruebas y observabilidad (MNT)


        ID                 Requisito                                             Criterio de verificación                                        Prioridad         Aplica en

        RNF-MNT-01         La solución separa las responsabilidades              El motor financiero puede ejecutarse y probarse                 Alta              Ambas
                           de presentación, API, dominio                         sin base de datos ni servicio de IA.
                           financiero, persistencia, procesamiento
                           documental e integración de IA
                           mediante interfaces bien definidas.

        RNF-MNT-02         El motor financiero y las reglas críticas             Cobertura de líneas de al menos 80 % en el                      Alta              Ambas
                           cuentan con pruebas unitarias                         motor financiero; las pruebas se ejecutan
                           automatizadas; los flujos de                          automáticamente en cada cambio.
                           autenticación, importación y simulación
                           cuentan con pruebas de integración.


                                                                                                                                                                                        19

---

### Página 20

ID                  Requisito                                            Criterio de verificación                                         Prioridad        Aplica en

        RNF-MNT-03          La configuración dependiente del                     El mismo artefacto se despliega en los tres                      Alta             Ambas
                            entorno se externaliza para ejecutar                 entornos cambiando solo la configuración.
                            desarrollo, pruebas y producción sin
                            modificar el código de negocio.

        RNF-MNT-04          La plataforma registra errores, latencia,            Dada una solicitud fallida, puede reconstruirse su               Alta             Ambas
                            fallos de importación y consumo de                   recorrido de extremo a extremo a partir de los
                            servicios externos (incluido el uso de IA)           registros.
                            con identificadores de correlación.

        RNF-MNT-05          La solución no requiere servicios de                 El equipo despliega y ejecuta la demo completa                   Crítica          Ambas
                            pago para desarrollarse, probarse ni                 con herramientas gratuitas, de código abierto o
                            demostrarse.                                         con capa gratuita, o en un equipo local; el costo
                                                                                 acumulado del proyecto es RD$0.







      5. Alcance y limitaciones del sistema

      5.1 Alcance

      5.1.1 Procesos cubiertos
      NexoFin AI cubre los siguientes procesos de la gestión financiera personal:

        #         Proceso                                       Descripción                                                                                        Nivel

        P1        Gestión de la cuenta del usuario              Registro, acceso seguro, perfil y recuperación de contraseña.                                      N1

        P2        Registro de movimientos                       Cuentas, transacciones (ingresos, gastos, transferencias, ajustes) y                               N1
                                                                transacciones recurrentes.

        P3        Gestión de deudas                             Deudas con calendario de cuotas y registro de pagos.                                               N1

        P4        Planificación                                 Presupuestos por categoría y metas de ahorro con aportes.                                          N1

        P5        Simulación de decisiones                      Simular un gasto y el ahorro para una meta; compra a cuotas, alternativas y                        N1 y N2
                                                                comparación.

        P6        Asistencia conversacional                     Consultas y escenarios en lenguaje natural con respuestas explicadas.                              N1

        P7        Visualización                                 Dashboard con balance y posición financiera; gráficos y tendencias.                                N1 a N3

        P8        Importación y categorización                  Categorización automática (N1) e importación de estados de cuenta CSV y                            N1 y N2
                                                                Excel (N2).

        P9        Alertas y notificaciones                      Avisos dentro de la aplicación (N2) y preferencias de canal (N3).                                  N2 y N3

        P10       Auditoría                                     Bitácora de acciones sensibles (N1) y consulta de actividad (N3).                                  N1 y N3






                                                                                                                                                                                        20

---

### Página 21

5.1.2 Niveles de entrega
     Para el plazo y los recursos del proyecto (sección 5.3), los requerimientos funcionales se ordenan en tres niveles. El nivel 1
     es el compromiso del equipo: una aplicación funcional de punta a punta. El nivel 2 se aborda solo si el nivel 1 está
     terminado y probado. El nivel 3 queda fuera del plazo actual. El nivel de cada RF aparece en la columna Nivel de la sección
     3.


        Nivel      Alcance                              Requerimientos funcionales                                                               Horas aprox.

        N1         Núcleo comprometido (37              AUT: 01, 03, 04, 05, 08 · CTA: 01, 05, 06, 07, 08 · TRX: 01, 02, 03, 04, 05,             440 a 490
                   RF)                                  06 · CAT: 01, 03, 05 · PRE: 01, 03, 04, 05 · SIM: 01, 02, 05, 06 · ASI: 01, 02,
                                                        03, 04, 05, 07, 08 · DAS: 01, 02 · AUD: 01. En ASI-08 solo el contexto de la
                                                        conversación.

        N2         Deseable si alcanza el               CTA: 03 · IMP: 01, 02, 03, 05, 06, 07 · CAT: 02, 06 · PRE: 02 · SIM: 03, 04,             200 a 250 adicionales
                   tiempo (16 RF)                       07 · ASI: 06 · NOT: 01 · DAS: 03. En IMP-01 e IMP-03 solo CSV y Excel.

        N3         Fuera del plazo actual (20           AUT: 02, 06, 07, 09, 10 · CTA: 02, 04, 09, 10 · IMP: 04, 08 · CAT: 04 · PRE:             más de 250
                   RF)                                  06 · SIM: 08 · NOT: 02, 03 · DAS: 04, 05 · AUD: 02, 03. Incluye el PDF de
                                                        IMP-01 e IMP-03 y el historial de ASI-08.

     Las horas son una estimación preliminar. Con una capacidad supuesta de unas 576 horas (4 personas, 12 semanas, 12 horas por semana),
     el nivel 1 casi agota el tiempo disponible: cualquier retraso debe absorberse recortando dentro del nivel 1 (lo primero en salir sería el
     desglose de cifras de RF-DAS-02) y no entrando al nivel 2.

     Qué puede hacer el usuario al terminar el nivel 1
       •   Registrarse, iniciar sesión, recuperar su contraseña y editar su perfil.
       •   Crear cuentas y deudas, registrar transacciones, transferencias y recurrentes, y consultar su historial.
       •   Ver sus movimientos categorizados automáticamente y corregir la categoría de cualquiera.
       •   Definir presupuestos y metas, registrar aportes y ver su progreso.
       •   Simular un gasto hipotético y el ahorro necesario para una meta, viendo los supuestos usados.
       •   Preguntar al asistente por sus datos y por escenarios hipotéticos y recibir respuestas con cifras del motor.
       •   Ver un dashboard con su balance, su posición financiera y su saldo libre proyectado.


     5.2 Fuera del alcance
       •   Aplicación móvil nativa: se ofrece una aplicación web adaptable a móvil.
       •   Conexión directa con bancos (open banking) o lectura automática de cuentas.
       •   Importación de estados de cuenta en PDF y OCR de documentos escaneados (nivel 3).
       •   Operación multimoneda con tasas de cambio (nivel 3): en el nivel 1 se opera solo en RD$.
       •   Contabilidad formal (partida doble, libro mayor) y declaración de impuestos.
       •   Inversiones, bolsa, criptoactivos y cálculo de rendimientos.
       •   Asesoría financiera regulada y recomendación de productos financieros.
       •   Pagos, transferencias o cualquier movimiento real de dinero.
       •   Cuentas compartidas o multiusuario (familias, empresas) y roles de administración o auditoría.
       •   Verificación de correo, autenticación en dos pasos, exportación de datos, eliminación de cuenta y notificaciones por
           correo (nivel 3).
       •   Operación en producción con alta disponibilidad, soporte y revisión legal formal (objetivos de producción).


                                                                                                                                                                             21

---

### Página 22

5.3 Limitaciones y restricciones
      •   Presupuesto: RD$0. No se admiten servicios ni licencias de pago; solo herramientas gratuitas, de código abierto o con
          capa gratuita. La demo puede ejecutarse en un equipo local.
      •   Plazo: 3 meses (12 semanas) hasta la entrega.
      •   Equipo: 4 estudiantes con dedicación parcial (se supone 12 horas por semana por persona, unas 576 horas en total).
      •   Dos entornos: la demo (entrega académica) y la producción (objetivo a futuro). Los RNF indican a cuál aplican; por
          ejemplo, la disponibilidad de 99,5 % y la revisión legal son solo de producción.
      •   Datos: la demo usa únicamente datos de prueba o sintéticos; no se procesan datos financieros reales de terceros.
      •   Idioma y moneda: interfaz y asistente en español, con RD$ como única moneda en el nivel 1.
      •   Asistente: en el nivel 1 es de solo lectura y funciona con un modo básico (reglas y plantillas) que no requiere modelo
          de pago; un modelo local o gratuito solo amplía la comprensión de preguntas no previstas. Su capacidad de
          interpretación es limitada y se mide con 50 preguntas de referencia.
      •   Alcance de las simulaciones: dependen de los datos que registre el usuario y de las reglas del Anexo B; no garantizan
          resultados futuros ni son asesoría financiera.
      •   Tecnología: este documento no la impone; se decide en el documento de arquitectura respetando el costo cero.
      •   Servicios gratuitos: pueden tener límites de uso o suspenderse por inactividad, por lo que no se garantiza
          disponibilidad continua en la demo.


     5.4 Supuestos y dependencias
      •   Los usuarios de la demo registran datos veraces y completos; la calidad de los resultados depende de ello.
      •   El equipo dispone de al menos un computador con recursos suficientes para ejecutar la demo (y el modelo local, si se
          usa).
      •   Las herramientas gratuitas necesarias siguen disponibles durante el proyecto.
      •   Los estados de cuenta de prueba (CSV o Excel) provienen de cuentas propias del equipo o se generan de forma
          sintética.
      •   Los usuarios acceden con un navegador moderno (sección 4.7).
      •   Las reglas de negocio del Anexo B se consideran acordadas y solo se modifican con acuerdo del equipo.


     5.5 Riesgos y mitigación


       #         Riesgo                                                Impacto         Mitigación

       R1        Reglas de negocio mal definidas o                     Alto            Congelar el Anexo B en la segunda semana y cubrirlo con pruebas
                 cambiantes, con un motor incorrecto como                              unitarias con resultados conocidos.
                 consecuencia.

       R2        El nivel 1 consume casi toda la capacidad y           Alto            Trabajar por niveles; no iniciar el nivel 2 sin el nivel 1 probado;
                 no queda margen para retrasos.                                        recortar dentro del nivel 1 si hace falta.

       R3        El asistente interpreta mal las preguntas sin         Medio           Modo básico con reglas y plantillas; medir con las 50 preguntas de
                 un modelo de pago.                                                    referencia; modelo local o gratuito solo como apoyo.

       R4        Los archivos CSV o Excel de cada banco                Medio           Mapeo manual de columnas (RF-IMP-02), plantilla propia y PDF
                 tienen formatos distintos.                                            diferido al nivel 3.

       R5        Los servicios gratuitos tienen límites o se           Medio           Ejecutar la demo en un equipo local; generar tareas programadas al
                 suspenden.                                                            iniciar sesión, no con un cron; medir con carga reducida.


                                                                                                                                                                         22

---

### Página 23

#         Riesgo                                                    Impacto          Mitigación

        R6        Dedicación desigual de los integrantes.                   Medio            Reparto por módulos con responsable, revisión semanal del avance y
                                                                                             repositorio único.

        R7        Uso de datos personales reales en pruebas.                Alto             Usar solo datos sintéticos; no cargar información de terceros.

        R8        Cambio de proveedor de IA o de sus límites                Medio            Interfaz desacoplada (RNF-MNT-01) y modo básico siempre
                  de uso.                                                                    disponible (RNF-IA-09).

      6. Diagrama de casos de uso

      Esta sección describe cómo interactúan los actores con NexoFin AI. Incluye los actores, el diagrama general, un catálogo de
      casos de uso por módulo con identificadores alineados a los requerimientos funcionales y la especificación detallada de
      los casos críticos. La trazabilidad con los RF está en el Anexo C.


      6.1 Actores


        Actor                                    Tipo                                  Descripción

        Usuario (Visitante)                      Humano, principal                     Persona sin sesión activa que se registra, inicia sesión o recupera su
                                                                                       contraseña.

        Usuario (Verificado)                     Humano, principal                     Persona con cuenta activa y sesión iniciada; usa todas las funciones
                                                                                       financieras. Aparece repetido en el diagrama solo por legibilidad.

        Servicio de correo                       Sistema externo, secundario           Envía los correos de verificación, recuperación de contraseña y
                                                                                       notificaciones.

        Proveedor de IA                          Sistema externo, secundario           Interpreta las preguntas del asistente y redacta explicaciones a partir de
                                                                                       resultados del motor financiero; no calcula cifras.

        Temporizador/Sistema                     Sistema interno, secundario           Dispara los procesos automáticos: generación de transacciones
                                                                                       recurrentes y de notificaciones y alertas.


























                                                                                                                                                                                    23

---

### Página 24

6.2 Diagrama general de casos de uso
     La figura 1 muestra los casos de uso del sistema completo (niveles 1 a 3). Un include indica un paso obligatorio del caso
     base; un extend indica un comportamiento opcional o condicional. El actor Usuario (Verificado) se repite por legibilidad.
     El nivel de entrega de cada caso está en el catálogo (6.3).






























































     Figura 1. Diagrama general de casos de uso de NexoFin AI.

                                                                                                                                                                  24

---

### Página 25

6.3 Catálogo de casos de uso por módulo
      El catálogo contiene 46 casos de uso. Los identificadores usan el mismo código de módulo que los RF (CU-AUT-01
      pertenece al módulo AUT). En la columna de actores, Visitante es Usuario (Visitante) y Verificado es Usuario (Verificado). El
      nivel indicado es el del primer requisito que cubre el caso; algunos casos completan su alcance en niveles posteriores. Las
      relaciones include y extend se indican en la descripción.

      6.3.1 Cuenta de usuario y autenticación (AUT)

        ID                Caso de uso                       Actores                 Descripción                                               RF / RNF              Nivel

        CU-AUT-01         Registrarse                       Visitante;              El visitante crea una cuenta con nombre,                  RF-AUT-01, 02         N1
                                                            Servicio de             correo y contraseña; incluye la verificación
                                                            correo                  del correo.

        CU-AUT-02         Verificar correo                  Visitante;              Incluido en Registrarse. El usuario confirma              RF-AUT-02             N3
                          electrónico                       Servicio de             su correo con un enlace de un solo uso.
                                                            correo

        CU-AUT-03         Iniciar sesión                    Visitante               Acceso con correo y contraseña, con bloqueo               RF-AUT-03             N1
                                                                                    temporal tras intentos fallidos.

        CU-AUT-04         Autenticar con segundo            Visitante               Extiende Iniciar sesión cuando el usuario                 RF-AUT-07             N3
                          factor                                                    tiene activada la autenticación en dos pasos.

        CU-AUT-05         Recuperar contraseña              Visitante;              Restablece el acceso mediante un enlace de                RF-AUT-05             N1
                                                            Servicio de             un solo uso enviado por correo.
                                                            correo

        CU-AUT-06         Cerrar sesión                     Verificado              Invalida la sesión activa.                                RF-AUT-04             N1

        CU-AUT-07         Reautenticar usuario              Verificado              Incluido en Cambiar contraseña, Eliminar                  RNF-SEG-04            N3
                                                                                    cuenta y Gestionar autenticación en dos
                                                                                    pasos: pide de nuevo la contraseña antes de
                                                                                    continuar.

        CU-AUT-08         Cambiar contraseña                Verificado              Cambia la contraseña previa reautenticación               RF-AUT-06             N3
                                                                                    e invalida las demás sesiones.

        CU-AUT-09         Gestionar autenticación           Verificado              Activa o desactiva el segundo factor;                     RF-AUT-07             N3
                          en dos pasos                                              desactivarlo exige reautenticación.

        CU-AUT-10         Configurar perfil y               Verificado              Edita nombre, moneda predeterminada,                      RF-AUT-08,            N1
                          preferencias                                              foto, formato de fecha y preferencias de                  RF-AUD-03,
                                                                                    notificación.                                             RF-NOT-02

        CU-AUT-11         Eliminar cuenta                   Verificado              Solicita la baja de la cuenta y de sus datos,             RF-AUT-09             N3
                                                                                    con reautenticación y confirmación.

        CU-AUT-12         Exportar mis datos                Verificado              Descarga una copia estructurada de todos                  RF-AUT-10             N3
                                                                                    sus datos.


      6.3.2 Cuentas, tarjetas y deudas (CTA)
      El caso del diagrama “Gestionar cuentas y deudas” se abre en CU-CTA-01 a CU-CTA-04.






                                                                                                                                                                                    25

---

### Página 26

ID                 Caso de uso                        Actores                  Descripción                                                 RF / RNF               Nivel

        CU-CTA-01          Gestionar cuentas                  Verificado               Registra, edita y archiva cuentas de efectivo,              RF-CTA-01 a            N1
                           financieras                                                 bancarias y tarjetas; consulta saldos, datos                05, 10
                                                                                       de tarjeta (límite, corte, pago) y tasa de
                                                                                       cambio.

        CU-CTA-02          Gestionar deudas                   Verificado               Registra deudas con su calendario de cuotas                 RF-CTA-06, 08          N1
                                                                                       y consulta su estado.

        CU-CTA-03          Registrar pago de deuda            Verificado               Registra un pago que descuenta la cuenta de                 RF-CTA-07              N1
                                                                                       origen y reduce el saldo pendiente.

        CU-CTA-04          Consultar calendario de            Verificado               Muestra cuotas, pagos de tarjeta y                          RF-CTA-09              N3
                           obligaciones                                                recurrentes de los próximos 60 días.

      6.3.3 Registro de transacciones (TRX)
      El caso del diagrama “Registrar transacción” se abre en CU-TRX-01 a CU-TRX-04.

        ID                 Caso de uso                        Actores                  Descripción                                                 RF / RNF              Nivel

        CU-TRX-01          Registrar transacción              Verificado               Registra un ingreso, gasto o ajuste; incluye la             RF-TRX-01             N1
                                                                                       categorización.

        CU-TRX-02          Registrar transferencia            Verificado               Mueve dinero entre cuentas propias en una                   RF-TRX-02             N1
                           entre cuentas                                               operación atómica que no cuenta como
                                                                                       ingreso ni gasto.

        CU-TRX-03          Editar transacción                 Verificado               Modifica una transacción, recalcula saldos y                RF-TRX-03             N1
                                                                                       conserva el valor anterior.

        CU-TRX-04          Eliminar transacción               Verificado               Da de baja lógica a una transacción, con                    RF-TRX-04             N1
                                                                                       confirmación.

        CU-TRX-05          Consultar historial de             Verificado               Busca y filtra transacciones por fecha,                     RF-TRX-05             N1
                           transacciones                                               cuenta, categoría, monto y texto.

        CU-TRX-06          Gestionar transacciones            Verificado               Define, pausa, edita y finaliza recurrencias                RF-TRX-06             N1
                           recurrentes                                                 (renta, suscripciones, nómina).

        CU-TRX-07          Generar transacciones              Temporizador/Si          Crea automáticamente la transacción de                      RF-TRX-06             N1
                           recurrentes                        stema                    cada periodo configurado.


      6.3.4 Importación y procesamiento documental (IMP)
      El caso del diagrama “Importar estado de cuenta” incluye además CU-IMP-03 (deshacer) como acción posterior.

        ID                 Caso de uso                        Actores                  Descripción                                                 RF / RNF              Nivel

        CU-IMP-01          Importar estado de                 Verificado               Sube un CSV, Excel o PDF, extrae los                        RF-IMP-01 a 05        N2
                           cuenta                                                      movimientos, detecta duplicados y los
                                                                                       categoriza; incluye la revisión.

        CU-IMP-02          Revisar transacciones              Verificado               Incluido   en Importar. El usuario edita,                   RF-IMP-06, 07         N2
                                                                                       excluye o aprueba cada movimiento y
                                                                                       confirma en bloque.

        CU-IMP-03          Deshacer importación               Verificado               Revierte una importación ya confirmada                      RF-IMP-08             N3
                                                                                       dentro de los 30 días siguientes.




                                                                                                                                                                                          26

---

### Página 27

6.3.5 Categorización de transacciones (CAT)
      El caso del diagrama “Gestionar categorías y reglas” se abre en CU-CAT-02 y CU-CAT-03.

        ID                 Caso de uso                        Actores                 Descripción                                                RF / RNF              Nivel

        CU-CAT-01          Categorizar                        Sistema                 Incluido en Registrar transacción e Importar.              RF-CAT-01, 06         N1
                           transacciones                                              Asigna la categoría o marca la transacción
                                                                                      como pendiente si la confianza es baja.

        CU-CAT-02          Gestionar categorías y             Verificado              Crea, edita y archiva categorías propias y                 RF-CAT-02, 04,        N1
                           reglas                                                     define reglas de categorización.                           05

        CU-CAT-03          Corregir categoría y               Verificado              Corrige la categoría de una transacción y                  RF-CAT-03, 06         N1
                           revisar pendientes                                         resuelve la bandeja de pendientes de
                                                                                      revisión.


      6.3.6 Presupuestos y metas (PRE)
      El caso del diagrama “Gestionar presupuestos y metas” se abre en CU-PRE-01 a CU-PRE-04.

        ID                 Caso de uso                       Actores                  Descripción                                                RF / RNF              Nivel

        CU-PRE-01          Gestionar presupuestos            Verificado               Define el presupuesto mensual por categoría                RF-PRE-01             N1
                                                                                      y consulta el porcentaje consumido.

        CU-PRE-02          Gestionar metas de                Verificado               Crea, edita, pausa y cierra metas con monto                RF-PRE-03, 06         N1
                           ahorro                                                     objetivo y fecha límite.

        CU-PRE-03          Registrar aporte a meta           Verificado               Registra un aporte desde una cuenta hacia                  RF-PRE-04             N1
                                                                                      una meta.

        CU-PRE-04          Consultar progreso de             Verificado               Muestra acumulado, porcentaje de avance y                  RF-PRE-05             N1
                           metas                                                      fecha estimada de cumplimiento.


      6.3.7 Simulación financiera (SIM)

        ID                 Caso de uso                       Actores                  Descripción                                                RF / RNF               Nivel

        CU-SIM-01          Simular escenario                 Verificado               Calcula   el efecto de un gasto, un ahorro para            RF-SIM-01, 02,         N1
                           financiero                                                 una meta o una compra a cuotas sobre saldo,                03, 05, 06
                                                                                      presupuestos y metas.

        CU-SIM-02          Consultar alternativas            Verificado               Extiende Simular cuando el escenario deja                  RF-SIM-04              N2
                                                                                      saldo negativo, excede un presupuesto o
                                                                                      compromete una meta.

        CU-SIM-03          Consultar historial de            Verificado               Reabre simulaciones guardadas con su                       RF-SIM-07              N2
                           simulaciones                                               resultado original.

        CU-SIM-04          Comparar escenarios               Verificado               Compara hasta tres escenarios lado a lado.                 RF-SIM-08              N3

      6.3.8 Asistente conversacional (ASI)

        ID                 Caso de uso                        Actores                 Descripción                                                RF / RNF              Nivel

        CU-ASI-01          Consultar asistente IA             Verificado;             Responde preguntas en lenguaje natural con                 RF-ASI-01 a 08        N1
                                                              Proveedor de IA         base en resultados del motor financiero y
                                                                                      mantiene el historial de conversaciones.




                                                                                                                                                                                        27

---

### Página 28

ID                 Caso de uso                       Actores                  Descripción                                                RF / RNF              Nivel

        CU-ASI-02          Simular por conversación          Verificado;              Extiende Consultar      asistente cuando la                RF-ASI-01 a 05,       N1
                                                             Proveedor de IA          pregunta es hipotética; incluye Simular                    RF-SIM-01 a 06
                                                                                      escenario financiero.

        CU-ASI-03          Gestionar                         Verificado               Extiende Consultar asistente: acepta o                     RNF-PRI-03            N1
                           consentimiento de IA                                       revoca el uso de servicios externos de IA.

      6.3.9 Notificaciones y alertas (NOT)

        ID                 Caso de uso                       Actores                  Descripción                                               RF / RNF              Nivel

        CU-NOT-01          Generar notificaciones y          Temporizador/Si          Genera avisos de presupuesto, vencimientos,               RF-NOT-01,            N2
                           alertas                           stema; Servicio          importaciones y metas y los envía por los                 RF-PRE-02
                                                             de correo                canales elegidos.

        CU-NOT-02          Consultar notificaciones          Verificado               Consulta el historial de notificaciones y las             RF-NOT-03             N3
                                                                                      marca como leídas.

      6.3.10 Dashboard y reportes (DAS)

        ID                 Caso de uso                       Actores                 Descripción                                                RF / RNF              Nivel

        CU-DAS-01          Visualizar dashboard y            Verificado              Muestra balance, posición financiera,                      RF-DAS-01 a 04        N1
                           reportes                                                  distribución del gasto y tendencias.

        CU-DAS-02          Exportar reporte                  Verificado              Exporta transacciones o el resumen del                     RF-DAS-05             N3
                                                                                     periodo a PDF o Excel.

      6.3.11 Auditoría (AUD)

        ID                 Caso de uso                       Actores                  Descripción                                                RF / RNF              Nivel

        CU-AUD-01          Consultar actividad de            Verificado               Muestra los inicios de sesión recientes y los              RF-AUD-02             N3
                           seguridad                                                  cambios de seguridad de la cuenta.

        CU-AUD-02          Registrar acciones                Sistema                  Transversal: cada caso sensible deja su                    RF-AUD-01             N1
                           sensibles en la bitácora                                   registro. No aparece en el diagrama porque
                                                                                      lo invocan los demás casos.


      6.4 Especificación de los casos de uso críticos
      Se detallan los casos que concentran el riesgo o el valor del sistema. El resto se especificará con el mismo formato
      durante el diseño.

      CU-AUT-01 · Registrarse

        Actores                             Usuario (Visitante); Servicio de correo (secundario)

        Precondición                        El visitante no tiene sesión activa ni una cuenta asociada al correo que va a usar.

        Postcondición                       La cuenta queda creada y verificada; sin verificación no puede registrar datos financieros. El registro queda en
                                            la bitácora.






                                                                                                                                                                                       28

---

### Página 29

Flujo principal                       1. El visitante abre la opción de registro.
                                               2. Ingresa nombre, correo electrónico y contraseña.
                                               3. El sistema valida el formato del correo, su unicidad y la política de contraseña.
                                               4. El sistema crea la cuenta en estado pendiente de verificación.
                                               5.            Incluye CU-AUT-02: el sistema pide al Servicio de correo enviar un enlace de verificación de un solo
                                               uso que expira en 24 horas.
                                               6. El visitante abre el enlace.
                                               7. El sistema marca la cuenta como verificada y lo confirma.
                                               8. El sistema registra la acción en la bitácora.

         Flujos alternativos y                 A. Correo ya registrado: el sistema rechaza el registro sin revelar datos de la cuenta existente.
         excepciones                           B. Contraseña fuera de política: indica los requisitos y no crea la cuenta.
                                               C. Enlace expirado o ya usado: permite solicitar uno nuevo.
                                               D. Servicio de correo no disponible: la cuenta queda pendiente y el usuario puede reintentar el envío.
                                               E. Límite de solicitudes superado: rechaza el intento con un mensaje claro.

         Nota de nivel                         En el nivel 1 no se exige verificar el correo (RF-AUT-02 es del nivel 3): la cuenta queda activa al registrarse y los
                                               pasos 5 a 7 no se ejecutan.

         Requisitos relacionados               Funcionales: RF-AUT-01, RF-AUT-02.
                                               No funcionales: RNF-SEG-02, RNF-SEG-06.

      CU-AUT-03 · Iniciar sesión

         Actores                               Usuario (Visitante). Extensión: CU-AUT-04 Autenticar con segundo factor.

         Precondición                          La cuenta existe y no está bloqueada temporalmente.

         Postcondición                         Sesión activa. El inicio de sesión queda en la bitácora.

         Flujo principal                       1. El usuario abre la pantalla de inicio de sesión.
                                               2. Ingresa correo y contraseña.
                                               3. El sistema valida las credenciales.
                                               4. Si la cuenta tiene autenticación en dos pasos activa, se ejecuta CU-AUT-04.
                                               5. El sistema crea la sesión.
                                               6. El sistema registra el inicio de sesión en la bitácora.
                                               7. El sistema muestra el dashboard.

         Flujos alternativos y                 A.            Credenciales inválidas: error genérico que no indica cuál campo falló; el intento se cuenta y se registra
         excepciones                           en la bitácora.
                                               B. Cinco intentos fallidos consecutivos: la cuenta se bloquea 15 minutos (valores configurables).
                                               C. Segundo factor inválido: se rechaza y cuenta como intento fallido.
                                               D.            Correo sin verificar: el sistema lo informa y ofrece reenviar el enlace; las funciones financieras
                                               siguen deshabilitadas.

         Nota de nivel                         En el nivel 1 la alternativa D no aplica, porque no existe verificación de correo.

         Requisitos relacionados               Funcionales: RF-AUT-03, RF-AUT-07, RF-AUD-01.
                                               No funcionales: RNF-SEG-04, RNF-SEG-06.

      CU-TRX-01 · Registrar transacción

         Actores                               Usuario (Verificado)

         Precondición                          Sesión activa y al menos una cuenta financiera activa.

         Postcondición                         La transacción queda guardada; el saldo de la cuenta y el presupuesto consumido se actualizan; la categoría
                                               queda asignada o pendiente de revisión.




                                                                                                                                                                                                  29

---

### Página 30

Flujo principal                      1. El usuario selecciona registrar una transacción.
                                              2. Elige el tipo: ingreso, gasto o ajuste (las transferencias usan CU-TRX-02).
                                              3. Ingresa monto, fecha, cuenta, categoría (opcional) y nota.
                                              4.           El sistema valida que el monto sea mayor que cero, que la fecha sea válida y que los campos
                                              obligatorios estén completos.
                                              5. Si no se eligió categoría, se ejecuta CU-CAT-01.
                                              6. El sistema guarda la transacción y recalcula el saldo de la cuenta en una sola operación atómica.
                                              7. El sistema actualiza el presupuesto consumido; si se supera el umbral configurado, se dispara CU-NOT-01.
                                              8. El sistema confirma el registro.

         Flujos alternativos y                A. Datos inválidos: el sistema no guarda y señala cada campo a corregir.
         excepciones                          B. Cuenta archivada: no admite movimientos nuevos.
                                              C.           La moneda de la cuenta es distinta de la moneda predeterminada: el sistema registra la tasa de
                                              cambio aplicada.
                                              D.           Confianza de clasificación baja: la transacción queda pendiente de revisión y no recibe
                                              categoría silenciosamente.
                                              E. Fallo al guardar: no queda ningún registro parcial ni saldo alterado.

         Requisitos relacionados              Funcionales: RF-TRX-01, RF-CAT-01, RF-CAT-06, RF-PRE-01, RF-PRE-02, RF-CTA-10. No
                                              funcionales: RNF-CON-02, RNF-DAT-01, RNF-DAT-02, RNF-DAT-04.

      CU-CTA-03 · Registrar pago de deuda

         Actores                              Usuario (Verificado)

         Precondición                         Sesión activa, deuda con saldo pendiente mayor que cero y cuenta de origen activa.

         Postcondición                        Queda registrado un gasto asociado al pago; el saldo de la cuenta y el saldo pendiente de la deuda se
                                              recalculan.

         Flujo principal                      1. El usuario selecciona una deuda y elige registrar un pago.
                                              2. Ingresa monto, fecha y cuenta de origen.
                                              3. El sistema valida los datos.
                                              4.           En una sola operación atómica, el sistema crea el gasto asociado, descuenta la cuenta de origen y
                                              recalcula el saldo pendiente y la próxima cuota.
                                              5. El sistema muestra el saldo pendiente y la fecha de la próxima cuota.

         Flujos alternativos y                A. Monto mayor que el saldo pendiente: el sistema lo rechaza e indica el saldo pendiente.
         excepciones                          B. Cuenta de origen archivada: no puede seleccionarse.
                                              C. Fallo durante la operación: no queda ningún cambio parcial.

         Requisitos relacionados              Funcionales: RF-CTA-07, RF-CTA-08.
                                              No funcionales: RNF-CON-02, RNF-CON-05, RNF-DAT-02.

      CU-IMP-01 · Importar estado de cuenta

         Actores                              Usuario (Verificado)

         Precondición                         Sesión activa y una cuenta de destino activa.

         Postcondición                        Los movimientos aprobados quedan guardados como transacciones categorizadas y sin duplicados
                                              silenciosos; el documento original se elimina según la política de retención; la importación queda en la
                                              bitácora.









                                                                                                                                                                                              30

---

### Página 31

Flujo principal                      1. El usuario elige importar y selecciona la cuenta de destino.
                                              2. Sube un archivo CSV, Excel o PDF.
                                              3. El sistema valida el tipo real, el tamaño y la integridad del archivo.
                                              4. Si es un CSV o Excel con columnas no reconocidas, el usuario indica cuál es fecha, monto y descripción.
                                              5.           El sistema procesa el archivo; si excede el tiempo interactivo, continúa en segundo plano y el usuario
                                              puede consultar su estado (en cola, procesando, lista para revisión, fallida).
                                              6. El sistema extrae fecha, monto, descripción y sentido de cada movimiento.
                                              7. El sistema detecta duplicados comparando la huella de cada movimiento con las transacciones existentes.
                                              8. Se ejecuta CU-CAT-01 para categorizar los movimientos.
                                              9. Incluye CU-IMP-02: el usuario revisa y confirma.
                                              10. El sistema registra la importación en la bitácora y programa la eliminación del documento original.

         Flujos alternativos y                A.           Archivo corrupto, de formato no soportado o demasiado grande: se rechaza con un mensaje
         excepciones                          claro sin afectar la sesión.
                                              B.           Documento sin texto extraíble (por ejemplo, una imagen escaneada) o ilegible: la importación falla e
                                              indica el motivo.
                                              C. Archivo ya importado: todos los movimientos se marcan como duplicados potenciales.
                                              D.           El usuario abandona sin confirmar: no se guarda nada y la importación caduca según la
                                              política de retención.
                                              E. Confirmada la importación, el usuario puede revertirla con CU-IMP-03 durante 30 días.

         Nota de nivel                        En el nivel 2 solo se admiten CSV y Excel; el PDF llega en el nivel 3.

         Requisitos relacionados              Funcionales: RF-IMP-01 a RF-IMP-05, RF-CAT-01.
                                              No funcionales: RNF-SEG-08, RNF-PRI-01, RNF-REN-03, RNF-CON-03.

      CU-IMP-02 · Revisar transacciones

         Actores                              Usuario (Verificado)

         Precondición                         Existe una importación en estado lista para revisión (incluido desde CU-IMP-01).

         Postcondición                        Los movimientos aprobados se guardan de forma atómica; los excluidos no se guardan; los saldos se
                                              recalculan.

         Flujo principal                      1.           El sistema muestra un resumen: movimientos detectados, duplicados potenciales y registros que
                                              requieren corrección.
                                              2. El usuario revisa cada movimiento y puede editarlo, excluirlo o aprobarlo.
                                              3. El usuario confirma la importación.
                                              4.           El sistema guarda todos los movimientos aprobados o ninguno, en una sola operación atómica, y
                                              recalcula los saldos.
                                              5. El sistema marca la importación como confirmada.

         Flujos alternativos y                A. El usuario cancela: no se guarda ningún movimiento.
         excepciones                          B. Fallo al guardar: no queda ningún movimiento parcial y el usuario es informado.
                                              C. Movimientos con confianza de clasificación baja: quedan pendientes de revisión de categoría.

         Requisitos relacionados              Funcionales: RF-IMP-06, RF-IMP-07.
                                              No funcionales: RNF-CON-02, RNF-CON-03.

      CU-SIM-01 · Simular escenario financiero

         Actores                              Usuario (Verificado)

         Precondición                         Sesión activa. Para obtener un resultado, deben existir datos suficientes (ver glosario).

         Postcondición                        El usuario obtiene el resultado con sus supuestos visibles; la simulación queda asociada a la versión de los
                                              datos, los parámetros y el resultado calculado; puede guardarse en el historial.




                                                                                                                                                                                              31

---

### Página 32

Flujo principal                       1. El usuario elige el tipo de escenario: gasto único, ahorro para una meta o compra a cuotas.
                                               2.            Ingresa los parámetros (por ejemplo: monto, categoría, fecha y horizonte; monto objetivo y fecha
                                               límite; o monto, tasa y número de cuotas).
                                               3. El sistema valida los parámetros.
                                               4. El motor financiero calcula el escenario base y el escenario simulado con datos persistidos.
                                               5.            El sistema muestra el saldo libre proyectado antes y después, y el efecto en presupuestos,
                                               metas y obligaciones próximas.
                                               6. El sistema muestra los supuestos y variables usados.
                                               7.            Si el escenario deja saldo libre negativo, excede un presupuesto o compromete una meta, se
                                               ofrece CU-SIM-02.
                                               8. El usuario puede guardar la simulación en su historial.

         Flujos alternativos y                 A. Datos insuficientes: el sistema explica qué falta y no presenta ninguna cifra como exacta.
         excepciones                           B. Parámetros inválidos: el sistema señala qué corregir.
                                               C.            Moneda distinta de la predeterminada: el cálculo usa la tasa de cambio registrada y la muestra
                                               entre los supuestos.

         Nota de nivel                         En el nivel 1 están disponibles el gasto único y el ahorro para una meta; la compra a cuotas y las alternativas
                                               llegan en el nivel 2.

         Requisitos relacionados               Funcionales: RF-SIM-01, 02, 03, 05, 06.
                                               No funcionales: RNF-IA-02, RNF-IA-03, RNF-IA-04, RNF-DAT-02.

      CU-ASI-01 · Consultar asistente IA

         Actores                               Usuario (Verificado); Proveedor de IA (secundario)

         Precondición                          Sesión activa, servicio de IA disponible y consentimiento vigente (si no lo hay, se ejecuta CU-ASI-03).

         Postcondición                         El usuario recibe una respuesta con su tipo de contenido indicado y cifras trazables; la conversación queda en
                                               su historial.

         Flujo principal                       1. El usuario escribe una pregunta en lenguaje natural.
                                               2. El sistema verifica el consentimiento y el límite de consultas.
                                               3.            El sistema envía al Proveedor de IA solo la información necesaria, sin identificadores personales
                                               directos ni números completos de cuenta, para identificar la intención y los parámetros.
                                               4.            Si la pregunta es descriptiva, el sistema ejecuta la operación correspondiente del motor
                                               financiero; si es hipotética, se ejecuta CU-ASI-02.
                                               5. Si falta un dato necesario, el asistente lo solicita al usuario.
                                               6. El Proveedor de IA redacta la explicación a partir del resultado del motor.
                                               7. El sistema verifica que toda cifra tenga origen en un dato persistido o en un cálculo del motor.
                                               8.            El sistema muestra la respuesta indicando si es un cálculo, una estimación o contenido educativo,
                                               con el aviso correspondiente y acceso al detalle del cálculo.
                                               9. El sistema guarda la conversación en el historial.

         Flujos alternativos y                 A. Sin consentimiento: se ejecuta CU-ASI-03 y no se envían datos al proveedor.
         excepciones                           B. Consulta ajena a las finanzas personales del usuario: el asistente responde que no puede atenderla.
                                               C. Datos insuficientes: el asistente lo declara en vez de estimar como exacto.
                                               D.            Servicio de IA no disponible: se muestra un aviso y el resto de la aplicación, incluida la
                                               simulación por formulario, sigue funcionando.
                                               E. Una cifra sin origen: se bloquea o se corrige antes de mostrar la respuesta.
                                               F.            Texto con instrucciones incrustadas en descripciones o documentos: se trata como dato y no
                                               altera el comportamiento del asistente.
                                               G.            La pregunta implica modificar datos: el asistente muestra un resumen y exige confirmación explícita
                                               antes de ejecutar.
                                               H. Límite diario de consultas alcanzado: el sistema lo informa con claridad.
                                               I. El usuario puede consultar y borrar su historial de conversaciones.





                                                                                                                                                                                                   32

---

### Página 33

Nota de nivel                       El consentimiento (CU-ASI-03) solo se solicita si la demo usa un proveedor externo de IA; con un modelo local o
                                             en modo básico ningún dato sale del equipo. En el nivel 1 el asistente es de solo lectura, por lo que la alternativa
                                             G no aplica hasta que existan acciones que modifiquen datos.

         Requisitos relacionados             Funcionales: RF-ASI-01 a RF-ASI-08.
                                             No funcionales: RNF-IA-01, IA-05, IA-06, IA-07, RNF-PRI-02, RNF-PRI-03.

      CU-ASI-02 · Simular por conversación

         Actores                             Usuario (Verificado); Proveedor de IA (secundario)

         Precondición                        Hay una consulta en curso en CU-ASI-01 cuya intención es un escenario hipotético.

         Postcondición                       El motor financiero ejecuta la simulación y el asistente explica el resultado; el usuario puede guardarla en el
                                             historial de simulaciones.

         Flujo principal                     1. El asistente identifica el escenario y sus parámetros (monto, categoría, fecha, horizonte).
                                             2. El asistente solicita al usuario los datos que falten.
                                             3. Incluye CU-SIM-01: el motor financiero ejecuta la simulación con esos parámetros.
                                             4. El asistente explica el resultado con los supuestos, la variación del saldo y las categorías afectadas.
                                             5. Si existen alternativas (CU-SIM-02), las presenta con el efecto numérico de cada una.

         Flujos alternativos y               A. Parámetros ambiguos: el asistente pide aclaración y no asume valores.
         excepciones                         B. Datos insuficientes: se declara y no se presenta una cifra como exacta.
                                             C. El usuario modifica un parámetro durante la conversación: se ejecuta una nueva simulación.

         Requisitos relacionados             Funcionales: RF-ASI-01 a 05, RF-SIM-01 a 06.
                                             No funcionales: RNF-IA-01, RNF-IA-02, RNF-IA-03, RNF-IA-04.

      Anexo A. Glosario y definiciones de trabajo

      Estas definiciones fijan el significado de los términos usados en los requisitos para que sean verificables. Las fórmulas que
      los usan están en el Anexo B.

        Término                                       Definición

        Motor financiero                              Componente determinístico que realiza todos los cálculos: saldos, presupuestos, proyecciones y
                                                      simulaciones.

        Modo básico del asistente                     Funcionamiento del asistente sin modelo de lenguaje: intenciones reconocidas por reglas y respuestas
                                                      redactadas con plantillas que insertan los valores del motor.

        Transacción                                   Movimiento de tipo ingreso, gasto, transferencia o ajuste. La transferencia entre cuentas propias no es
                                                      ingreso ni gasto.

        Ajuste                                        Movimiento que corrige la diferencia entre el saldo registrado y el saldo real de una cuenta.

        Saldo disponible                              Suma de los saldos de las cuentas de efectivo y bancarias activas. Excluye tarjetas de crédito y cuentas
                                                      archivadas.

        Ingreso esperado                              Ingreso registrado como recurrente que aún no ha ocurrido dentro del periodo analizado.

        Gasto fijo                                    Gasto recurrente, cuota de deuda o pago de tarjeta con monto y fecha conocidos.

        Saldo libre proyectado                        Para una fecha F: saldo disponible actual, más ingresos esperados hasta F, menos gastos fijos con
                                                      vencimiento hasta F, menos los aportes comprometidos a metas hasta F.

        Presupuesto consumido                         Porcentaje que resulta de dividir el gasto del mes en una categoría entre el presupuesto definido para
                                                      ella.

        Meta de ahorro / aporte                       Objetivo de acumular un monto en una fecha límite / monto que el usuario destina a esa meta.

                                                                                                                                                                                           33

---

### Página 34

Término                                      Definición

        Escenario                                    Conjunto de parámetros hipotéticos que el usuario plantea (por ejemplo, un gasto de RD$20,000 en
                                                     ocio el día 15).

        Escenario base                               Proyección financiera del usuario sin ninguna decisión hipotética, calculada solo con datos registrados.

        Simulación / supuesto                        Resultado del motor al aplicar un escenario sobre el escenario base / dato o parámetro utilizado para
                                                     calcularlo.

        Datos insuficientes                          Situación en la que no hay ingresos esperados registrados o no existe historial de al menos un mes
                                                     completo; los parámetros son configurables.

        Huella de transacción                        Combinación de cuenta, fecha, monto y descripción normalizada usada para reconocer duplicados.

        Confianza de clasificación                   Medida de qué tan seguro está el sistema de la categoría asignada; por debajo del umbral, la
                                                     transacción queda pendiente de revisión.

        Sin categoría                                Estado de una transacción que ninguna regla ni palabra clave logró clasificar; no se le asigna una
                                                     categoría por suposición.

        Baja lógica / archivar                       Marcar un registro como inactivo sin borrarlo físicamente, conservando su historial y trazabilidad.

        Periodo                                      Mes calendario, salvo que el usuario seleccione otro rango.

        Demo / producción                            Demo: entrega académica ejecutada con recursos gratuitos y datos de prueba. Producción: objetivo a
                                                     futuro con usuarios reales.

        Nivel de entrega                             Agrupación de requisitos por orden de construcción (N1 comprometido, N2 deseable, N3 futuro).

      Anexo B. Reglas de negocio

      Las reglas de negocio fijan cómo calcula y decide el sistema. Son independientes de la tecnología y todo componente
      debe aplicarlas de forma uniforme. Los valores numéricos son configurables salvo indicación contraria.


      B.1 Datos y precisión


        ID                   Regla                                                                                                                 Requisitos

        RN-DAT-01            Los importes tienen 2 decimales y se redondean con la regla “mitad hacia arriba” (0.005 pasa                          RNF-DAT-02
                             a 0.01) una sola vez, al final de cada cálculo individual.

        RN-DAT-02            En el nivel 1 la única moneda es el peso dominicano (RD$). Con multimoneda (nivel 3) cada                             RF-CTA-01, 10
                             importe conserva su moneda y toda conversión usa la tasa registrada.

        RN-DAT-03            El periodo por defecto es el mes calendario y las fechas se interpretan en la zona horaria                            RNF-DAT-04
                             America/Santo_Domingo.

        RN-DAT-04            Ningún registro financiero se borra físicamente: eliminar es una baja lógica y toda edición                           RF-TRX-03, 04, CTA-04
                             conserva el valor anterior.

      B.2 Cuentas


        ID                   Regla                                                                                                                 Requisitos

        RN-CTA-01            Saldo de una cuenta = saldo inicial + ingresos - gastos + transferencias recibidas -                                  RF-CTA-05, RNF-CON-05
                             transferencias enviadas +/- ajustes, considerando solo movimientos activos.




                                                                                                                                                                                        34

---

### Página 35

ID                    Regla                                                                                                                    Requisitos

        RN-CTA-02             Las cuentas de efectivo y bancarias suman al saldo disponible. La tarjeta de crédito no suma:                            RF-CTA-01, 02
                              se trata como una cuenta cuyo saldo negativo es lo adeudado, y su pago se registra como
                              transferencia desde otra cuenta.

        RN-CTA-03             Una cuenta con movimientos no se elimina, se archiva; una cuenta archivada no admite                                     RF-CTA-04
                              movimientos nuevos.

      B.3 Transacciones


        ID                    Regla                                                                                                                    Requisitos

        RN-TRX-01             Los montos se ingresan siempre positivos y el tipo define el efecto: el ingreso suma, el gasto                           RF-TRX-01, 02
                              resta, la transferencia resta en el origen y suma en el destino, y el ajuste aumenta o disminuye
                              el saldo según lo elija el usuario.

        RN-TRX-02             Una transacción manual no puede tener fecha posterior a hoy. Las recurrentes se generan en                               RF-TRX-01, 06
                              su fecha de vencimiento.

        RN-TRX-03             La transferencia entre cuentas propias no es ingreso ni gasto: no cuenta en balances,                                    RF-TRX-02, DAS-01
                              presupuestos ni tendencias.

        RN-TRX-04             Una recurrente genera una transacción por cada fecha vencida aún no generada, incluso si el                              RF-TRX-06
                              usuario no abrió la aplicación; la generación ocurre al iniciar sesión o al consultar.

        RN-TRX-05             Editar, pausar o finalizar una recurrente no altera las transacciones ya generadas.                                      RF-TRX-06

      B.4 Deudas


        ID                    Regla                                                                                                                    Requisitos

        RN-DEU-01             Cuota fija (sistema francés): cuota = P × r / (1 - (1 + r)^(-n)), donde P es el monto original, r la                     RF-CTA-06, SIM-03
                              tasa mensual (tasa anual ÷ 12) y n el número de cuotas. Si la tasa es 0, cuota = P ÷ n.

        RN-DEU-02             En cada cuota, interés = saldo de capital × r y capital = cuota - interés. La última cuota se                            RF-CTA-06
                              ajusta para dejar el saldo en cero.

        RN-DEU-03             Un pago se aplica a la cuota pendiente más antigua; si excede la cuota, cubre las siguientes                             RF-CTA-07
                              en orden. No se admite un pago mayor que el saldo pendiente total.

        RN-DEU-04             Saldo pendiente de una deuda = suma del capital de sus cuotas no pagadas.                                                RF-CTA-06, 07, 08, DAS-02

      B.5 Categorización


        ID                    Regla                                                                                                                    Requisitos

        RN-CAT-01             Precedencia de la clasificación: 1) regla del usuario, 2) corrección manual previa para la                               RF-CAT-01, 02, 03
                              misma descripción normalizada, 3) palabras clave del sistema, 4) “Sin categoría”.

        RN-CAT-02             Si se usa un clasificador con confianza (nivel 2), toda transacción por debajo del umbral                                RF-CAT-06
                              configurado queda pendiente de revisión y no recibe categoría.

        RN-CAT-03             Una corrección manual nunca se sobrescribe por un reprocesamiento automático.                                            RF-CAT-03






                                                                                                                                                                                             35

---

### Página 36

B.6 Simulación


        ID                    Regla                                                                                                                     Requisitos

        RN-SIM-01             Ingresos esperados hasta F = suma de las ocurrencias futuras, hasta la fecha F, de las                                    RF-SIM-01, 02
                              transacciones recurrentes de ingreso.

        RN-SIM-02             Gastos fijos hasta F = ocurrencias futuras de las recurrentes de gasto + cuotas de deuda                                  RF-SIM-01, 02
                              pendientes con vencimiento hasta F. En el nivel 3 se suman los pagos de tarjeta.

        RN-SIM-03             Saldo libre proyectado (F) = saldo disponible actual + ingresos esperados hasta F - gastos fijos                          RF-SIM-01, DAS-02
                              hasta F - aportes comprometidos a metas hasta F.

        RN-SIM-04             Simular un gasto de monto M en la fecha D: el saldo libre proyectado después es el de antes                               RF-SIM-01
                              menos M para toda fecha F posterior o igual a D. Su efecto en el presupuesto es (gasto del
                              mes + M) ÷ presupuesto de la categoría. Las metas quedan comprometidas cuando el saldo
                              libre proyectado después es negativo.

        RN-SIM-05             El ahorro para una meta es viable cuando el aporte mensual requerido es menor o igual que el                              RF-SIM-02
                              ingreso mensual esperado menos los gastos fijos mensuales del mes siguiente; si no lo es, se
                              informa el déficit mensual.

        RN-SIM-06             Compra a cuotas: la cuota se calcula con RN-DEU-01; costo total = cuota × n; intereses = costo  RF-SIM-03
                              total - monto; el efecto mensual es la cuota restada del saldo libre proyectado de cada mes
                              del plazo.

        RN-SIM-07             Alternativas cuando el saldo libre proyectado queda negativo o se excede un presupuesto: a)                               RF-SIM-04
                              posponer el gasto al primer mes en que el saldo libre proyectado después no sea negativo; b)
                              recortar categorías variables por el monto del déficit, repartido en proporción al gasto
                              promedio de los últimos 3 meses de cada categoría; c) reducir temporalmente el aporte a
                              una meta hasta cubrir el déficit. Cada alternativa muestra su efecto numérico.

        RN-SIM-08             Con datos insuficientes (sin ingresos esperados o con menos de 1 mes completo de historial)                               RF-SIM-06, RNF-IA-03
                              el motor devuelve “no concluyente”, indica qué falta y no entrega ninguna cifra final.

        RN-SIM-09             Todo resultado se guarda con la copia de los datos usados y los parámetros; recalcular con                                RF-SIM-07, RNF-IA-04
                              esa copia produce exactamente el mismo resultado.


        ID                    Regla                                                                                                                     Requisitos

        RN-SIM-10             El horizonte por defecto es el fin del mes en curso y el máximo es de 12 meses.                                           RF-SIM-01

      B.7 Asistente


        ID                    Regla                                                                                                                    Requisitos

        RN-ASI-01             El asistente solo presenta cifras que provienen de un dato persistido o de un resultado del                              RNF-IA-01
                              motor; una cifra sin origen se bloquea o se corrige antes de mostrarse.

        RN-ASI-02             En el nivel 1 el asistente solo consulta y simula: no crea, modifica ni elimina datos. Cualquier                         RF-ASI-06
                              acción que cambie datos exige confirmación explícita.

        RN-ASI-03             El texto de descripciones, notas y documentos importados es dato, nunca instrucción.                                     RNF-IA-05

        RN-ASI-04             Toda respuesta con cifras se etiqueta como cálculo con datos del usuario, estimación o                                   RF-ASI-05
                              contenido educativo.

        RN-ASI-05             Las consultas ajenas a las finanzas personales del usuario se rechazan con un mensaje                                    RF-ASI-07
                              informativo.

                                                                                                                                                                                             36

---

### Página 37

RN-ASI-06            Cada usuario puede hacer un máximo de 50 consultas al asistente por día (configurable).                                 RNF-IA-06

      B.8 Importación


        ID                   Regla                                                                                                                   Requisitos

        RN-IMP-01            El sentido de cada movimiento importado define su tipo: débito es gasto y crédito es ingreso.                           RF-IMP-03

        RN-IMP-02            Huella = cuenta + fecha + monto + descripción normalizada (minúsculas, sin acentos, espacios                            RF-IMP-05
                             colapsados). Una coincidencia con una transacción existente es un duplicado potencial y nunca
                             se descarta sin que el usuario lo vea.

        RN-IMP-03            Una importación se confirma completa o no se guarda, y puede deshacerse dentro de los 30                                RF-IMP-07, 08
                             días siguientes.

        RN-IMP-04            El documento original se elimina como máximo 24 horas después de procesarlo, salvo                                      RNF-PRI-01
                             autorización expresa del usuario.

      B.9       Seguridad


        ID                   Regla                                                                                                                   Requisitos

        RN-SEG-01            La contraseña tiene al menos 10 caracteres y no figura en una lista de contraseñas comunes.                             RF-AUT-01

        RN-SEG-02            Tras 5 intentos fallidos consecutivos de inicio de sesión, la cuenta se bloquea 15 minutos.                             RF-AUT-03

        RN-SEG-03            La sesión expira tras 30 minutos de inactividad.                                                                        RNF-SEG-04

        RN-SEG-04            Son acciones sensibles auditadas: inicio y fallo de inicio de sesión, cambios de seguridad,                             RF-AUD-01
                             importación, eliminación de datos y exportación. La bitácora no se edita ni se elimina y no
                             guarda datos sensibles en claro.

        RN-SEG-05            Un usuario solo accede a sus propios datos; la autorización se valida siempre en el servidor.                           RNF-SEG-05




























                                                                                                                                                                                          37
