INCLUDE Irvine32.inc

MAX_PRODUCTOS EQU 10

; ----------------------------------------------------------------
; Define la estructura de cada videojuego: codigo, nombre, precio y existencias.
; ----------------------------------------------------------------
PRODUCTO STRUCT
  codigo BYTE 8 DUP(0)
  nombre BYTE 26 DUP(0)
  precio DWORD 0
  existencias DWORD 0
PRODUCTO ENDS

; ================================================================
; MACROS DEL SISTEMA
; ================================================================

; Imprime una cadena terminada en cero ubicada en .data.
mImprimirTexto MACRO etiquetaTexto
  mov edx,OFFSET etiquetaTexto
  call MostrarTexto
ENDM

; Muestra un mensaje indicador y captura texto en el bufer entrada.
mPedirCadena MACRO etiquetaPrompt
  mov edx,OFFSET etiquetaPrompt
  call PedirTexto
ENDM

; Prepara EDX (direccion de entrada) y ECX (longitud en EAX) para conversion.
mPrepararEntrada MACRO
  mov edx,OFFSET entrada
  mov ecx,eax
ENDM

; Verifica que 'reg' este dentro del rango inclusivo [minVal, maxVal].
mValidarRango MACRO reg, minVal, maxVal, etiquetaError
  cmp reg,minVal
  jb etiquetaError
  cmp reg,maxVal
  ja etiquetaError
ENDM

; Imprime una etiqueta seguida de un entero sin signo y salto de linea.
mMostrarDatoEntero MACRO etiquetaTexto, valorEntero
  mImprimirTexto etiquetaTexto
  mov eax,valorEntero
  call MostrarEntero
  call Crlf
ENDM

; Imprime una etiqueta seguida de un importe formateado en pesos MXN.
mMostrarDatoPrecio MACRO etiquetaTexto, valorCentavos
  mImprimirTexto etiquetaTexto
  mov eax,valorCentavos
  call MostrarPrecio
ENDM

; Solicita y valida un entero dentro de [minVal, maxVal] con mensaje indicador.
mLeerEnteroRango MACRO etiquetaPrompt, minVal, maxVal
  mov edx,OFFSET etiquetaPrompt
  mov edi,minVal
  mov ebx,maxVal
  call LeerEntero
ENDM

; Imprime un mensaje de alerta si 'valor' es menor o igual a 'limite'.
mImprimirSiMenorIgual MACRO valor, limite, etiquetaAlerta
  LOCAL omitirAlerta
  cmp valor,limite
  ja omitirAlerta
  mImprimirTexto etiquetaAlerta
omitirAlerta:
ENDM

; Rellena con ceros 'cantidad' bytes a partir de 'destino'.
mLimpiarBytes MACRO destino, cantidad
  mov edi,destino
  mov ecx,cantidad
  xor eax,eax
  rep stosb
ENDM

; Copia 'cantidad' bytes desde 'origen' hacia 'destino'.
mCopiarBytes MACRO origen, destino, cantidad
  mov esi,origen
  mov edi,destino
  mov ecx,cantidad
  rep movsb
ENDM

; Cierra el archivo indicado si su manejador es valido y lo reinicia.
mCerrarArchivo MACRO manejador
  LOCAL yaCerrado
  mov eax,manejador
  cmp eax,INVALID_HANDLE_VALUE
  je yaCerrado
  call CloseFile
  mov manejador,INVALID_HANDLE_VALUE
yaCerrado:
ENDM

; Compara AL con 'caracter' y salta a 'destino' si coinciden.
mSaltarSiOpcion MACRO caracter, destino
  cmp al,caracter
  je destino
ENDM

.data
menuPrincipal BYTE 13,10,'=== TIENDA GameStop ===',13,10,'1.- Registrar Producto ',13,10,'2.- Mostrar Inventario ',13,10,'3.- Buscar Articulo ',13,10,'4.- Recibir Mercancia',13,10,'5.- Vender',13,10,'6.- Resumen de Movimientos ',13,10,'7.- Guardar Catalogo',13,10,'8.- Cargar Catalogo',13,10,'0.- Salir',13,10,'Opcion: ',0
pedirCodigo BYTE 'Codigo (ej: ABC-123): ',0
pedirNombre BYTE 'Nombre (1-25): ',0
pedirPrecio BYTE 'Precio MXN: ',0
pedirExistencias BYTE 'Existencia (0-100): ',0
pedirCantidad BYTE 'Cantidad (>0): ',0
mensajeInvalido BYTE 'Dato invalido o fuera de rango.',13,10,0
mensajeNoEncontrado BYTE 'Producto no encontrado.',13,10,0
mensajeDuplicado BYTE 'Codigo duplicado.',13,10,0
mensajeLleno BYTE 'Capacidad de 10 productos alcanzada.',13,10,0
mensajeExito BYTE 'Operacion realizada.',13,10,0
mensajeSinExistencias BYTE 'Existencia insuficiente o limite excedido.',13,10,0
mensajeErrorArchivo BYTE 'Error de archivo o datos invalidos. Catalogo conservado.',13,10,0
mensajeGuardado BYTE 'Catalogo guardado.',13,10,0
mensajeCargado BYTE 'Catalogo cargado.',13,10,0
avisoCambios BYTE 'Hay cambios sin guardar. Salir? (S/N): ',0
avisoPocasExistencias BYTE ' *** ALERTA: existencia minima ***',0
etiquetaCodigo BYTE 'Codigo: ',0
etiquetaNombre BYTE '  Nombre: ',0
etiquetaPrecio BYTE '  Precio: ',0
etiquetaExistencias BYTE '  Unidades: ',0
etiquetaUnidades BYTE 'Unidades disponibles: ',0
etiquetaValor BYTE 'Valor inventario: ',0
etiquetaIngresos BYTE 'Ingresos de esta sesion: ',0
etiquetaVenta BYTE 'Importe de venta: ',0
textoMXN BYTE ' MXN',13,10,0
nombreArchivo BYTE 'inventario.dat',0
entrada BYTE 128 DUP(0)
bufferNumero BYTE 16 DUP(0)

; ----------------------------------------------------------------
; Arreglo de hasta diez registros PRODUCTO, almacenados consecutivamente.
; ----------------------------------------------------------------
catalogo PRODUCTO MAX_PRODUCTOS DUP(<>)
temporal PRODUCTO MAX_PRODUCTOS DUP(<>)
cantidadProductos DWORD 0
cantidadNueva DWORD 0

; ----------------------------------------------------------------
; Acumula el dinero cobrado durante esta sesion, expresado en centavos.
; ----------------------------------------------------------------
ingresos DWORD 0
cambiosPendientes BYTE 0
manejadorArchivo DWORD INVALID_HANDLE_VALUE
cabeceraArchivo DWORD 324E5649h
cantidadArchivo DWORD 0

; ----------------------------------------------------------------
; Espacio para la cabecera, cantidad de registros y productos del archivo binario.
; ----------------------------------------------------------------
bufferArchivo BYTE (8+MAX_PRODUCTOS*SIZEOF PRODUCTO) DUP(0)

.code

; ----------------------------------------------------------------
; Imprime en consola una cadena terminada en cero.
; Recibe:   EDX = direccion de la cadena.
; Devuelve: Nada.
; Conserva: EAX, ECX, EDX.
; ----------------------------------------------------------------
MostrarTexto PROC USES eax ecx edx
  call WriteString
  ret
MostrarTexto ENDP

; ----------------------------------------------------------------
; Muestra un mensaje indicador y lee texto desde teclado en 'entrada'.
; Recibe:   EDX = direccion del mensaje indicador.
; Devuelve: EAX = longitud de la cadena capturada.
; Conserva: ECX, EDX (EAX queda fuera de USES para entregar resultado).
; ----------------------------------------------------------------
PedirTexto PROC USES ecx edx
  call WriteString
  mov edx,OFFSET entrada
  mov ecx,SIZEOF entrada-1
  call ReadString
  ret
PedirTexto ENDP

; ----------------------------------------------------------------
; Convierte una cadena de digitos ASCII a un entero sin signo de 32 bits.
; Recibe:   EDX = direccion de la cadena, ECX = longitud.
; Devuelve: EAX = entero convertido y CF = 0; CF = 1 si es invalido.
; Conserva: EBX, ECX, EDX, ESI, EDI.
; ----------------------------------------------------------------
ConvertirEntero PROC USES ebx ecx edx esi edi
  mov esi,edx
  test ecx,ecx
  jz enteroInvalido

  xor edi,edi

cicloEntero:
  movzx ebx,BYTE PTR [esi]
  mValidarRango ebx, '0', '9', enteroInvalido
  sub ebx,'0'
  mov eax,edi
  mov edx,10
  mul edx
  test edx,edx
  jnz enteroInvalido

  add eax,ebx
  jc enteroInvalido

  mov edi,eax
  inc esi
  dec ecx
  jnz cicloEntero

  mov eax,edi
  clc
  ret

enteroInvalido:
  stc
  ret
ConvertirEntero ENDP

; ----------------------------------------------------------------
; Convierte un precio decimal escrito como texto a centavos enteros.
; Recibe:   EDX = direccion de la cadena, ECX = longitud.
; Devuelve: EAX = importe en centavos (1..999999) y CF = 0; CF = 1 si falla.
; Conserva: EBX, ECX, EDX, ESI, EDI, EBP.
; ----------------------------------------------------------------
ConvertirPrecio PROC USES ebx ecx edx esi edi ebp
  mov esi,edx
  test ecx,ecx
  jz precioInvalido

  xor edi,edi
  xor ebp,ebp
  xor ebx,ebx

cicloPrecio:
  movzx eax,BYTE PTR [esi]
  cmp al,'.'
  je puntoDecimal

  mValidarRango al, '0', '9', precioInvalido
  sub eax,'0'
  cmp ebp,0
  jne digitoDecimal

  inc ebx
  cmp edi,9999
  ja precioInvalido

  imul edi,edi,10
  add edi,eax
  cmp edi,9999
  ja precioInvalido
  jmp siguientePrecio

digitoDecimal:
  cmp ebp,3
  jae precioInvalido

  imul edi,edi,10
  add edi,eax
  inc ebp
  jmp siguientePrecio

puntoDecimal:
  test ebx,ebx
  jz precioInvalido

  test ebp,ebp
  jnz precioInvalido

  mov ebp,1

siguientePrecio:
  inc esi
  dec ecx
  jnz cicloPrecio

  test ebx,ebx
  jz precioInvalido

  cmp ebp,1
  je precioInvalido

  cmp ebp,0
  jne comprobarPrecio

  imul edi,edi,100
  jmp limitePrecio

comprobarPrecio:
  cmp ebp,2
  jne limitePrecio

  imul edi,edi,10

limitePrecio:
  mValidarRango edi, 1, 999999, precioInvalido
  mov eax,edi
  clc
  ret

precioInvalido:
  stc
  ret
ConvertirPrecio ENDP

; ----------------------------------------------------------------
; Solicita texto, lo convierte a entero y valida minimo (EDI) y maximo (EBX).
; Recibe:   EDX = mensaje indicador, EDI = minimo, EBX = maximo.
; Devuelve: EAX = entero validado y CF = 0; imprime error y CF = 1 si falla.
; Conserva: EBX, ECX, EDX, ESI, EDI.
; ----------------------------------------------------------------
LeerEntero PROC USES ebx ecx edx esi edi
  call PedirTexto
  mPrepararEntrada
  call ConvertirEntero
  jc lecturaInvalida

  mValidarRango eax, edi, ebx, lecturaInvalida
  clc
  ret

lecturaInvalida:
  mImprimirTexto mensajeInvalido
  stc
  ret
LeerEntero ENDP

; ----------------------------------------------------------------
; Solicita un precio decimal y delega su conversion a ConvertirPrecio.
; Recibe:   Nada.
; Devuelve: EAX = precio en centavos y CF = 0; imprime error y CF = 1 si falla.
; Conserva: ECX, EDX.
; ----------------------------------------------------------------
LeerPrecio PROC USES ecx edx
  mPedirCadena pedirPrecio
  mPrepararEntrada
  call ConvertirPrecio
  jnc precioLeido

  mImprimirTexto mensajeInvalido
  stc

precioLeido:
  ret
LeerPrecio ENDP

; ----------------------------------------------------------------
; Comprueba que una cadena cumpla el formato exacto ABC-123.
; Recibe:   EDX = direccion de la cadena terminada en cero.
; Devuelve: EAX = 1 si el formato es valido; EAX = 0 en caso contrario.
; Conserva: ECX, ESI.
; ----------------------------------------------------------------
ValidarCodigo PROC USES ecx esi
  mov esi,edx
  mov ecx,3

validarLetras:
  mov al,[esi]
  mValidarRango al, 'A', 'Z', codigoInvalido
  inc esi
  loop validarLetras

  cmp BYTE PTR [esi],'-'
  jne codigoInvalido

  inc esi
  mov ecx,3

validarDigitos:
  mov al,[esi]
  mValidarRango al, '0', '9', codigoInvalido
  inc esi
  loop validarDigitos

  cmp BYTE PTR [esi],0
  jne codigoInvalido

  mov eax,1
  ret

codigoInvalido:
  xor eax,eax
  ret
ValidarCodigo ENDP

; ----------------------------------------------------------------
; Solicita un codigo al usuario y comprueba su longitud (7) y formato.
; Recibe:   Nada.
; Devuelve: EAX = 7 y CF = 0 si es valido; imprime error y CF = 1 si falla.
; Conserva: EDX.
; ----------------------------------------------------------------
LeerCodigo PROC USES edx
  mPedirCadena pedirCodigo
  cmp eax,7
  jne capturaCodigoInvalida

  mov edx,OFFSET entrada
  call ValidarCodigo
  test eax,eax
  jz capturaCodigoInvalida

  mov eax,7
  clc
  ret

capturaCodigoInvalida:
  mImprimirTexto mensajeInvalido
  stc
  ret
LeerCodigo ENDP

; ----------------------------------------------------------------
; Valida que un nombre tenga terminador nulo y longitud entre 1 y 25.
; Recibe:   EDI = direccion del bufer de nombre (maximo 26 bytes).
; Devuelve: EAX = longitud (1..25) y CF = 0 si es valido; CF = 1 si falla.
; Conserva: ECX, EDI.
; ----------------------------------------------------------------
ValidarLongitudNombre PROC USES ecx edi
  xor ecx,ecx

cicloLongitudNombre:
  cmp ecx,26
  jae longitudNombreInvalida

  cmp BYTE PTR [edi+ecx],0
  je verificarRangoNombre

  inc ecx
  jmp cicloLongitudNombre

verificarRangoNombre:
  mValidarRango ecx, 1, 25, longitudNombreInvalida
  mov eax,ecx
  clc
  ret

longitudNombreInvalida:
  stc
  ret
ValidarLongitudNombre ENDP

; ----------------------------------------------------------------
; Solicita el nombre de un producto y valida su longitud (1..25).
; Recibe:   Nada.
; Devuelve: EAX = longitud (1..25) y CF = 0 si es valido; CF = 1 si falla.
; Conserva: ECX, EDX.
; ----------------------------------------------------------------
LeerNombreProducto PROC USES ecx edx
  mPedirCadena pedirNombre
  mValidarRango eax, 1, 25, nombreInvalido
  clc
  ret

nombreInvalido:
  mImprimirTexto mensajeInvalido
  stc
  ret
LeerNombreProducto ENDP

; ----------------------------------------------------------------
; Compara dos codigos de 7 caracteres apuntados por ESI y EDI.
; Recibe:   ESI = direccion del primer codigo, EDI = direccion del segundo.
; Devuelve: EAX = 1 si los 7 bytes coinciden; EAX = 0 si difieren.
; Conserva: ECX, ESI, EDI.
; ----------------------------------------------------------------
CompararCodigos PROC USES ecx esi edi
  mov ecx,7

cicloCompararCodigos:
  mov al,[esi]
  cmp al,[edi]
  jne codigosDistintos

  inc esi
  inc edi
  loop cicloCompararCodigos

  mov eax,1
  ret

codigosDistintos:
  xor eax,eax
  ret
CompararCodigos ENDP

; ----------------------------------------------------------------
; Calcula la direccion en memoria de un registro dentro de 'catalogo'.
; Recibe:   EAX = indice del producto (0 .. MAX_PRODUCTOS - 1).
; Devuelve: ESI = direccion efectiva del registro PRODUCTO.
; Conserva: EAX (ESI queda fuera de USES para entregar resultado).
; ----------------------------------------------------------------
ObtenerDireccionProducto PROC USES eax
  imul eax,SIZEOF PRODUCTO
  lea esi,catalogo[eax]
  ret
ObtenerDireccionProducto ENDP

; ----------------------------------------------------------------
; Busca un codigo de 7 caracteres en 'catalogo'.
; Recibe:   EDX = direccion del codigo a buscar.
; Devuelve: EAX = indice (0 .. cantidadProductos - 1) o -1 si no existe.
; Conserva: EBX, ECX, EDX, ESI, EDI.
; ----------------------------------------------------------------
EncontrarCodigo PROC USES ebx ecx edx esi edi
  mov edi,edx
  xor ebx,ebx
  mov esi,OFFSET catalogo

siguienteProducto:
  cmp ebx,cantidadProductos
  jae codigoNoExiste

  call CompararCodigos
  test eax,eax
  jnz codigoEncontrado

  add esi,SIZEOF PRODUCTO
  inc ebx
  jmp siguienteProducto

codigoEncontrado:
  mov eax,ebx
  ret

codigoNoExiste:
  mov eax,-1
  ret
EncontrarCodigo ENDP

; ----------------------------------------------------------------
; Solicita un codigo y entrega en ESI la direccion del producto encontrado.
; Recibe:   Nada.
; Devuelve: ESI = direccion del producto y CF = 0; imprime error y CF = 1 si falla.
; Conserva: EAX, EDX (ESI queda fuera de USES para entregar resultado).
; ----------------------------------------------------------------
LocalizarProducto PROC USES eax edx
  call LeerCodigo
  jc localizacionInvalida

  mov edx,OFFSET entrada
  call EncontrarCodigo
  cmp eax,-1
  je productoNoExiste

  call ObtenerDireccionProducto
  clc
  ret

productoNoExiste:
  mImprimirTexto mensajeNoEncontrado

localizacionInvalida:
  stc
  ret
LocalizarProducto ENDP

; ----------------------------------------------------------------
; Convierte un entero sin signo a decimal y lo imprime en consola.
; Recibe:   EAX = numero entero sin signo.
; Devuelve: Nada.
; Conserva: EAX, EBX, ECX, EDX, ESI.
; ----------------------------------------------------------------
MostrarEntero PROC USES eax ebx ecx edx esi
  mov esi,OFFSET bufferNumero+15
  mov BYTE PTR [esi],0
  mov ebx,10

extraerDigito:
  xor edx,edx
  div ebx
  add dl,'0'
  dec esi
  mov [esi],dl
  test eax,eax
  jnz extraerDigito

  mov edx,esi
  call MostrarTexto
  ret
MostrarEntero ENDP

; ----------------------------------------------------------------
; Separa pesos y centavos para imprimir importes con dos decimales.
; Recibe:   EAX = importe expresado en centavos.
; Devuelve: Nada.
; Conserva: EAX, EBX, EDX.
; ----------------------------------------------------------------
MostrarPrecio PROC USES eax ebx edx
  xor edx,edx
  mov ebx,100
  div ebx
  push edx
  call MostrarEntero
  mov al,'.'
  call WriteChar
  pop eax
  cmp eax,10
  jae dosDecimales

  push eax
  mov al,'0'
  call WriteChar
  pop eax

dosDecimales:
  call MostrarEntero
  mImprimirTexto textoMXN
  ret
MostrarPrecio ENDP

; ----------------------------------------------------------------
; Imprime los datos completos de un producto apuntado por ESI.
; Recibe:   ESI = direccion del registro PRODUCTO.
; Devuelve: Nada.
; Conserva: EAX, EDX.
; ----------------------------------------------------------------
MostrarProducto PROC USES eax edx
  mImprimirTexto etiquetaCodigo
  mov edx,esi
  call MostrarTexto
  mImprimirTexto etiquetaNombre
  lea edx,[esi].PRODUCTO.nombre
  call MostrarTexto
  call Crlf
  mMostrarDatoPrecio etiquetaPrecio, [esi].PRODUCTO.precio
  mImprimirTexto etiquetaExistencias
  mov eax,[esi].PRODUCTO.existencias
  call MostrarEntero
  mImprimirSiMenorIgual DWORD PTR [esi].PRODUCTO.existencias, 5, avisoPocasExistencias
  call Crlf
  ret
MostrarProducto ENDP

; ----------------------------------------------------------------
; Recorre todos los productos registrados y los muestra en pantalla.
; Recibe:   Nada.
; Devuelve: Nada.
; Conserva: EAX, ECX, ESI.
; ----------------------------------------------------------------
MostrarInventario PROC USES eax ecx esi
  mov esi,OFFSET catalogo
  mov ecx,cantidadProductos
  test ecx,ecx
  jz finInventario

cicloInventario:
  call MostrarProducto
  add esi,SIZEOF PRODUCTO
  loop cicloInventario

finInventario:
  ret
MostrarInventario ENDP

; ----------------------------------------------------------------
; Valida y registra un videojuego nuevo sin permitir codigos repetidos.
; Recibe:   Nada.
; Devuelve: Nada (actualiza catalogo, cantidadProductos y cambiosPendientes).
; Conserva: EAX, EBX, ECX, EDX, ESI, EDI.
; ----------------------------------------------------------------
RegistrarProducto PROC USES eax ebx ecx edx esi edi
  cmp cantidadProductos,MAX_PRODUCTOS
  jae altaLlena

  call LeerCodigo
  jc finAlta

  mov edx,OFFSET entrada
  call EncontrarCodigo
  cmp eax,-1
  jne altaDuplicada

  mLimpiarBytes OFFSET temporal, SIZEOF PRODUCTO
  mCopiarBytes OFFSET entrada, OFFSET temporal.codigo, 7

  call LeerNombreProducto
  jc finAlta

  mCopiarBytes OFFSET entrada, OFFSET temporal.nombre, eax

  call LeerPrecio
  jc finAlta

  mov temporal.precio,eax
  mLeerEnteroRango pedirExistencias, 0, 100
  jc finAlta

  mov temporal.existencias,eax
  mov eax,cantidadProductos
  call ObtenerDireccionProducto
  mov edi,esi
  mCopiarBytes OFFSET temporal, edi, SIZEOF PRODUCTO

  inc cantidadProductos
  mov cambiosPendientes,1
  mImprimirTexto mensajeExito
  ret

altaLlena:
  mImprimirTexto mensajeLleno
  ret

altaDuplicada:
  mImprimirTexto mensajeDuplicado

finAlta:
  ret
RegistrarProducto ENDP

; ----------------------------------------------------------------
; Busca un producto por codigo y muestra su informacion.
; Recibe:   Nada.
; Devuelve: Nada.
; Conserva: ESI.
; ----------------------------------------------------------------
BuscarProducto PROC USES esi
  call LocalizarProducto
  jc finBusqueda

  call MostrarProducto

finBusqueda:
  ret
BuscarProducto ENDP

; ----------------------------------------------------------------
; Aumenta existencias de un producto respetando el limite maximo de 100.
; Recibe:   Nada.
; Devuelve: Nada (actualiza existencias y cambiosPendientes).
; Conserva: EAX, EBX, EDX, ESI, EDI.
; ----------------------------------------------------------------
RecibirMercancia PROC USES eax ebx edx esi edi
  call LocalizarProducto
  jc finRecepcion

  mLeerEnteroRango pedirCantidad, 1, 100
  jc finRecepcion

  mov ebx,[esi].PRODUCTO.existencias
  add ebx,eax
  cmp ebx,100
  ja recepcionExcesiva

  mov [esi].PRODUCTO.existencias,ebx
  mov cambiosPendientes,1
  mImprimirTexto mensajeExito
  ret

recepcionExcesiva:
  mImprimirTexto mensajeSinExistencias

finRecepcion:
  ret
RecibirMercancia ENDP

; ----------------------------------------------------------------
; Calcula el importe total de una venta y valida desbordamientos de 32 bits.
; Recibe:   EAX = precio unitario en centavos, ECX = cantidad vendida.
; Devuelve: EAX = importe total y CF = 0 si es valido; CF = 1 si desborda.
; Conserva: ECX, EDX.
; ----------------------------------------------------------------
CalcularImporteVenta PROC USES ecx edx
  mul ecx
  test edx,edx
  jnz importeDesbordado

  mov edx,ingresos
  add edx,eax
  jc importeDesbordado

  clc
  ret

importeDesbordado:
  stc
  ret
CalcularImporteVenta ENDP

; ----------------------------------------------------------------
; Valida existencias, calcula venta sin descuentos y actualiza ingresos.
; Recibe:   Nada.
; Devuelve: Nada (actualiza existencias, ingresos y cambiosPendientes).
; Conserva: EAX, EBX, ECX, EDX, ESI, EDI.
; ----------------------------------------------------------------
VenderProducto PROC USES eax ebx ecx edx esi edi
  call LocalizarProducto
  jc finVenta

  mMostrarDatoEntero etiquetaExistencias, [esi].PRODUCTO.existencias
  mLeerEnteroRango pedirCantidad, 1, 100
  jc finVenta

  mov ecx,eax
  cmp ecx,[esi].PRODUCTO.existencias
  ja ventaRechazada

  mov eax,[esi].PRODUCTO.precio
  call CalcularImporteVenta
  jc ventaRechazada

  mov ebx,eax
  add ingresos,ebx
  sub [esi].PRODUCTO.existencias,ecx
  mov cambiosPendientes,1

  call Crlf
  mMostrarDatoEntero etiquetaUnidades, [esi].PRODUCTO.existencias
  mMostrarDatoPrecio etiquetaVenta, ebx
  ret

ventaRechazada:
  mImprimirTexto mensajeSinExistencias

finVenta:
  ret
VenderProducto ENDP

; ----------------------------------------------------------------
; Muestra existencias por producto, total de unidades, valor e ingresos.
; Recibe:   Nada.
; Devuelve: Nada.
; Conserva: EAX, EBX, ECX, EDX, ESI, EDI.
; ----------------------------------------------------------------
MostrarResumen PROC USES eax ebx ecx edx esi edi
  xor edi,edi
  xor ebx,ebx
  mov esi,OFFSET catalogo
  mov ecx,cantidadProductos

cicloResumen:
  test ecx,ecx
  jz imprimirResumen

  lea edx,[esi].PRODUCTO.nombre
  call MostrarTexto
  mMostrarDatoEntero etiquetaExistencias, [esi].PRODUCTO.existencias

  add edi,[esi].PRODUCTO.existencias
  mov eax,[esi].PRODUCTO.precio
  mul [esi].PRODUCTO.existencias
  add ebx,eax
  add esi,SIZEOF PRODUCTO
  dec ecx
  jmp cicloResumen

imprimirResumen:
  mMostrarDatoEntero etiquetaUnidades, edi
  mMostrarDatoPrecio etiquetaValor, ebx
  mMostrarDatoPrecio etiquetaIngresos, ingresos
  ret
MostrarResumen ENDP

; ----------------------------------------------------------------
; Valida todos los campos y la unicidad de un registro leido del archivo.
; Recibe:   ESI = direccion del registro en bufferArchivo, EBX = indice (0..N-1).
; Devuelve: CF = 0 si el registro es integro y unico; CF = 1 si es invalido.
; Conserva: EAX, EBX, ECX, EDX, ESI, EDI.
; ----------------------------------------------------------------
ValidarRegistroArchivo PROC USES eax ebx ecx edx esi edi
  lea edx,[esi].PRODUCTO.codigo
  cmp BYTE PTR [edx+7],0
  jne registroArchivoInvalido

  call ValidarCodigo
  test eax,eax
  jz registroArchivoInvalido

  lea edi,[esi].PRODUCTO.nombre
  call ValidarLongitudNombre
  jc registroArchivoInvalido

  mov eax,[esi].PRODUCTO.precio
  mValidarRango eax, 1, 999999, registroArchivoInvalido

  cmp DWORD PTR [esi].PRODUCTO.existencias,100
  ja registroArchivoInvalido

  mov edi,OFFSET bufferArchivo+8
  mov ecx,ebx

cicloUnicidadArchivo:
  test ecx,ecx
  jz registroArchivoValido

  call CompararCodigos
  test eax,eax
  jnz registroArchivoInvalido

  add edi,SIZEOF PRODUCTO
  dec ecx
  jmp cicloUnicidadArchivo

registroArchivoValido:
  clc
  ret

registroArchivoInvalido:
  stc
  ret
ValidarRegistroArchivo ENDP

; ----------------------------------------------------------------
; Escribe la cabecera y registros del catalogo en inventario.dat.
; Recibe:   Nada.
; Devuelve: Nada.
; Conserva: EAX, EBX, ECX, EDX, ESI, EDI.
; ----------------------------------------------------------------
GuardarInventario PROC USES eax ebx ecx edx esi edi
  mov manejadorArchivo,INVALID_HANDLE_VALUE
  mov eax,cantidadProductos
  mov cantidadArchivo,eax

  mov edi,OFFSET bufferArchivo
  mov eax,cabeceraArchivo
  stosd
  mov eax,cantidadProductos
  stosd

  mov ecx,cantidadProductos
  imul ecx,SIZEOF PRODUCTO
  mCopiarBytes OFFSET catalogo, edi, ecx

  mov edx,OFFSET nombreArchivo
  call CreateOutputFile
  cmp eax,INVALID_HANDLE_VALUE
  je errorGuardado

  mov manejadorArchivo,eax
  mov ebx,cantidadProductos
  imul ebx,SIZEOF PRODUCTO
  add ebx,8

  mov edx,OFFSET bufferArchivo
  mov ecx,ebx
  call WriteToFile
  cmp eax,ebx
  jne errorGuardado

  mCerrarArchivo manejadorArchivo
  mov cambiosPendientes,0
  mImprimirTexto mensajeGuardado
  ret

errorGuardado:
  mCerrarArchivo manejadorArchivo
  mImprimirTexto mensajeErrorArchivo
  ret
GuardarInventario ENDP

; ----------------------------------------------------------------
; Lee y valida el archivo binario antes de reemplazar el catalogo actual.
; Recibe:   Nada.
; Devuelve: Nada.
; Conserva: EAX, EBX, ECX, EDX, ESI, EDI, EBP.
; ----------------------------------------------------------------
CargarInventario PROC USES eax ebx ecx edx esi edi ebp
  mov manejadorArchivo,INVALID_HANDLE_VALUE
  mov edx,OFFSET nombreArchivo
  call OpenInputFile
  cmp eax,INVALID_HANDLE_VALUE
  je errorCarga

  mov manejadorArchivo,eax
  mov edx,OFFSET bufferArchivo
  mov ecx,SIZEOF bufferArchivo
  call ReadFromFile
  jc errorCarga

  mov ebp,eax
  mCerrarArchivo manejadorArchivo

  cmp ebp,8
  jb errorCarga

  cmp DWORD PTR bufferArchivo,324E5649h
  jne errorCarga

  mov eax,DWORD PTR bufferArchivo+4
  cmp eax,MAX_PRODUCTOS
  ja errorCarga

  mov cantidadNueva,eax
  imul eax,SIZEOF PRODUCTO
  add eax,8
  cmp eax,ebp
  jne errorCarga

  mov esi,OFFSET bufferArchivo+8
  xor ebx,ebx

validarRegistro:
  cmp ebx,cantidadNueva
  jae confirmarCarga

  call ValidarRegistroArchivo
  jc errorCarga

  add esi,SIZEOF PRODUCTO
  inc ebx
  jmp validarRegistro

confirmarCarga:
  mov ecx,cantidadNueva
  imul ecx,SIZEOF PRODUCTO
  mCopiarBytes OFFSET bufferArchivo+8, OFFSET catalogo, ecx

  mov eax,cantidadNueva
  mov cantidadProductos,eax
  mov ingresos,0
  mov cambiosPendientes,0
  mImprimirTexto mensajeCargado
  ret

errorCarga:
  mCerrarArchivo manejadorArchivo
  mImprimirTexto mensajeErrorArchivo
  ret
CargarInventario ENDP

; ----------------------------------------------------------------
; Punto de entrada: carga catalogo inicial y procesa el menu principal.
; ----------------------------------------------------------------
main PROC
  call CargarInventario

cicloMenu:
  mPedirCadena menuPrincipal
  cmp eax,1
  jne opcionInvalida

  mov al,entrada
  mSaltarSiOpcion '0', opcionSalir
  mSaltarSiOpcion '1', opcionAlta
  mSaltarSiOpcion '2', opcionMostrar
  mSaltarSiOpcion '3', opcionBuscar
  mSaltarSiOpcion '4', opcionRecibir
  mSaltarSiOpcion '5', opcionVender
  mSaltarSiOpcion '6', opcionResumen
  mSaltarSiOpcion '7', opcionGuardar
  mSaltarSiOpcion '8', opcionCargar

opcionInvalida:
  mImprimirTexto mensajeInvalido
  jmp cicloMenu

opcionAlta:
  call RegistrarProducto
  jmp cicloMenu

opcionMostrar:
  call MostrarInventario
  jmp cicloMenu

opcionBuscar:
  call BuscarProducto
  jmp cicloMenu

opcionRecibir:
  call RecibirMercancia
  jmp cicloMenu

opcionVender:
  call VenderProducto
  jmp cicloMenu

opcionResumen:
  call MostrarResumen
  jmp cicloMenu

opcionGuardar:
  call GuardarInventario
  jmp cicloMenu

opcionCargar:
  call CargarInventario
  jmp cicloMenu

opcionSalir:
  cmp cambiosPendientes,0
  je mainEnd

  mPedirCadena avisoCambios
  cmp eax,1
  jne cicloMenu

  mov al,entrada
  mSaltarSiOpcion 'S', guardarAlSalir
  mSaltarSiOpcion 's', guardarAlSalir
  jmp mainEnd

guardarAlSalir:
  call GuardarInventario

mainEnd:
  exit
main ENDP

END main