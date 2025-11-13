import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Formulario Accesible',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AccessibleFormScreen(),
    );
  }
}

class AccessibleFormScreen extends StatefulWidget {
  @override
  _AccessibleFormScreenState createState() => _AccessibleFormScreenState();
}

class _AccessibleFormScreenState extends State<AccessibleFormScreen> {
  final FlutterTts flutterTts = FlutterTts();
  final stt.SpeechToText speechToText = stt.SpeechToText();
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos de texto
  TextEditingController _nombreController = TextEditingController();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _telefonoController = TextEditingController();
  TextEditingController _mensajeController = TextEditingController();
  TextEditingController _paisController = TextEditingController();

  String _selectedOption = 'Opción 1';
  bool _aceptoTerminos = false;

  // Variables para control de voz
  bool _isListening = false;
  bool _ttsEnabled = true;
  double _ttsVolume = 1.0;
  String? _currentListeningField;

  Map<String, String> countryCodes = {
    'colombia': '+57',
    'mexico': '+52',
    'argentina': '+54',
    'peru': '+51',
    'chile': '+56',
    'ecuador': '+593',
    'venezuela': '+58',
    'uruguay': '+598',
    'paraguay': '+595',
    'bolivia': '+591',
    'brasil': '+55',
    'costa rica': '+506',
    'panama': '+507',
    'guatemala': '+502',
    'el salvador': '+503',
    'honduras': '+504',
    'nicaragua': '+505',
    'república dominicana': '+1-809', // República Dominicana usa +1 con varios códigos
    'cuba': '+53',
  };

  @override
  void initState() {
    super.initState();
    _initTts();
    _initSpeech();
      // Listener para actualizar prefijo si el usuario escribe el país
    _paisController.addListener(() {
      String textoPais = _paisController.text.toLowerCase();
      if (countryCodes.containsKey(textoPais)) {
        String prefix = countryCodes[textoPais]!;
        // Solo actualizar si no está ya agregado
        if (!_telefonoController.text.startsWith(prefix)) {
          _telefonoController.text = prefix + ' ';
          _speak("Se agregó el prefijo $prefix para ${_paisController.text}");
        }
      }
    });
  }

  _initTts() async {
    await flutterTts.setLanguage("es-ES");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(_ttsVolume);
  }

  _initSpeech() async {
    bool available = await speechToText.initialize(
      onStatus: (status) {
        print('Speech status: $status');
        if (status == 'done') {
          setState(() {
            _isListening = false;
            _currentListeningField = null;
          });
        }
      },
      onError: (error) {
        print('Speech error: $error');
        setState(() {
          _isListening = false;
          _currentListeningField = null;
        });
      },
    );

    if (!available) {
      _speak("El reconocimiento de voz no está disponible");
    }
  }

  _speak(String text) async {
    if (text.isNotEmpty && _ttsEnabled) {
      await flutterTts.speak(text);
    }
  }

  _stopTts() async {
    await flutterTts.stop();
  }

  _toggleTTS() {
    setState(() {
      _ttsEnabled = !_ttsEnabled;
    });
    _speak(_ttsEnabled ? "Voz activada" : "Voz desactivada");
  }

  _changeVolume(double volume) {
    setState(() {
      _ttsVolume = volume;
    });
    flutterTts.setVolume(volume);
  }

  _readFieldDescription(String fieldName, String description) {
    _speak("Campo $fieldName. $description");
  }

  // Procesar texto para convertir "arroba" por "@"
  String _processEmailText(String text) {
    return text
        .replaceAll(' arroba ', '@')
        .replaceAll('arroba', '@')
        .replaceAll(' arroba', '@')
        .replaceAll('arroba ', '@');
  }

  // Llenado individual de un campo específico
  _startFieldVoiceInput(
    String fieldName,
    TextEditingController controller, {
    bool isEmail = false,
  }) async {
    // Si ya está escuchando este campo, detener
    if (_isListening && _currentListeningField == fieldName) {
      await _stopListening();
      return;
    }

    // Detener cualquier TTS en curso
    await _stopTts();

    // Detener cualquier grabación previa
    if (_isListening) {
      await speechToText.stop();
    }

    setState(() {
      _isListening = true;
      _currentListeningField = fieldName;
    });

    await _listenForField(fieldName, controller, isEmail: isEmail);
  }

  _listenForField(
    String fieldName,
    TextEditingController controller, {
    bool isEmail = false,
  }) async {
    await speechToText.listen(
      onResult: (result) {
        if (result.finalResult) {
          String recognizedText = result.recognizedWords;
          if (recognizedText.isNotEmpty) {
            // Procesar texto si es email
            if (isEmail) {
              recognizedText = _processEmailText(recognizedText);
            }
            _fillField(fieldName, controller, recognizedText);
          }
        }
      },
      listenFor: Duration(seconds: 10),
      pauseFor: Duration(seconds: 3),
      partialResults: true,
      localeId: "es_ES",
    );
  }

  _fillField(String fieldName, TextEditingController controller, String text) {
    setState(() {
      controller.text = text;
      _isListening = false;
      _currentListeningField = null;
    });

    // Si es el campo país, actualizar teléfono
    // Si es el campo país, actualizar teléfono
    if (fieldName.toLowerCase() == 'país') {
      String prefix = countryCodes[text.toLowerCase()] ?? '';
      if (prefix.isNotEmpty) {
        _telefonoController.text = prefix + ' ';
        _speak("Se agregó el prefijo $prefix para $text");
      }
    }


    // Confirmación breve y opcional
    if (_ttsEnabled) {
      _speak("Campo $fieldName llenado");
    }
  }


  // Escuchar para seleccionar opción del dropdown
  _startDropdownVoiceInput() async {
    if (_isListening && _currentListeningField == 'dropdown') {
      await _stopListening();
      return;
    }

    await _stopTts();

    if (_isListening) {
      await speechToText.stop();
    }

    setState(() {
      _isListening = true;
      _currentListeningField = 'dropdown';
    });

    _speak(
      "¿Qué opción desea seleccionar? Diga opción uno, dos, tres o cuatro",
    );

    await speechToText.listen(
      onResult: (result) {
        if (result.finalResult) {
          final recognizedText = result.recognizedWords.toLowerCase();
          _processDropdownVoiceInput(recognizedText);
        }
      },
      listenFor: Duration(seconds: 8),
      pauseFor: Duration(seconds: 3),
      partialResults: true,
      localeId: "es_ES",
    );
  }

  _processDropdownVoiceInput(String text) {
    String? selectedOption;

    if (text.contains('uno') ||
        text.contains('1') ||
        text.contains('primera')) {
      selectedOption = 'Opción 1';
    } else if (text.contains('dos') ||
        text.contains('2') ||
        text.contains('segunda')) {
      selectedOption = 'Opción 2';
    } else if (text.contains('tres') ||
        text.contains('3') ||
        text.contains('tercera')) {
      selectedOption = 'Opción 3';
    } else if (text.contains('cuatro') ||
        text.contains('4') ||
        text.contains('cuarta')) {
      selectedOption = 'Opción 4';
    }

    if (selectedOption != null) {
      setState(() {
        _selectedOption = selectedOption!;
        _isListening = false;
        _currentListeningField = null;
      });
      _speak("Seleccionada $selectedOption");
    } else {
      _speak(
        "No se reconoció la opción. Por favor diga opción uno, dos, tres o cuatro",
      );
      setState(() {
        _isListening = false;
        _currentListeningField = null;
      });
    }
  }

  // Envío del formulario por voz
  _startSubmitVoiceInput() async {
    if (_isListening && _currentListeningField == 'submit') {
      await _stopListening();
      return;
    }

    await _stopTts();

    if (_isListening) {
      await speechToText.stop();
    }

    setState(() {
      _isListening = true;
      _currentListeningField = 'submit';
    });

    _speak(
      "¿Desea enviar el formulario? Diga sí para enviar o no para cancelar",
    );

    await speechToText.listen(
      onResult: (result) {
        if (result.finalResult) {
          final recognizedText = result.recognizedWords.toLowerCase();
          _processSubmitVoiceInput(recognizedText);
        }
      },
      listenFor: Duration(seconds: 8),
      pauseFor: Duration(seconds: 3),
      partialResults: true,
      localeId: "es_ES",
    );
  }

  _processSubmitVoiceInput(String text) {
    setState(() {
      _isListening = false;
      _currentListeningField = null;
    });

    if (text.contains('sí') || text.contains('si') || text.contains('enviar')) {
      _submitForm();
    } else if (text.contains('no') || text.contains('cancelar')) {
      _speak("Envío cancelado");
    } else {
      _speak(
        "No se reconoció la respuesta. Use el botón para enviar manualmente",
      );
    }
  }

  _stopListening() async {
    await _stopTts();
    await speechToText.stop();
    setState(() {
      _isListening = false;
      _currentListeningField = null;
    });
  }

  _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (!_aceptoTerminos) {
        _speak("Debe aceptar los términos y condiciones");
        return;
      }

      _speak("Formulario enviado correctamente. Gracias por registrarse");
      // Aquí procesarías el formulario
    } else {
      _speak("Por favor, corrija los errores en el formulario");
    }
  }

  double _zoom = 1.0; // Factor de zoom (1.0 = normal, 1.5 = 150%)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 236, 233, 233), // Aquí pones el color que quieras
      appBar: AppBar(
        title: Text('FORMULARIO ACCESIBLE'),
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: Color.fromARGB(255, 255, 255, 255), // Cambia el color del texto
          fontSize: 20,        // Tamaño del texto
          fontWeight: FontWeight.bold, // Negrita
        ),
        backgroundColor: const Color.fromARGB(255, 44, 185, 255), // También puedes cambiar el color del AppBar
        actions: [
          IconButton(
            icon: Icon(
              _ttsEnabled ? Icons.volume_up : Icons.volume_off,
              color: Colors.white, // <-- aquí lo pones blanco
            ),
            onPressed: _toggleTTS,
            tooltip: _ttsEnabled ? 'Silenciar voz' : 'Activar voz',
          ),
          if (_isListening)
            IconButton(
              icon: Icon(Icons.stop, color: Colors.red),
              onPressed: _stopListening,
              tooltip: 'Detener reconocimiento de voz',
            ),
          
        ],
      ),
      
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Transform.scale(
          scale: _zoom,
          alignment: Alignment.topCenter,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

              Column(
                crossAxisAlignment: CrossAxisAlignment.start, // Alinea todo a la izquierda
                children: [
                  // Línea divisoria o volumen arriba
                  _buildVolumeControls(),
                  SizedBox(height: 10),
                  Divider(color: Colors.grey, thickness: 1),
                  SizedBox(height: 10),

                  // Controles de zoom lado a lado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start, // Alinea a la izquierda
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _zoom += 0.1;
                            if (_zoom > 2.0) _zoom = 2.0;
                          });
                        },
                        icon: Icon(Icons.zoom_in),
                        label: Text("Zoom +"),
                      ),
                      SizedBox(width: 10), // espacio entre botones
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _zoom -= 0.1;
                            if (_zoom < 1.0) _zoom = 1.0;
                          });
                        },
                        icon: Icon(Icons.zoom_out),
                        label: Text("Zoom -"),
                      ),
                    ],
                  ),

                  SizedBox(height: 20),
                  // Resto del formulario...
                ],
              ),
  

              SizedBox(height: 20),
              
              
            
              // Título
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Complete el formulario:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.record_voice_over),
                    onPressed:
                        () => _speak(
                          "Formulario de registro. Use los botones de micrófono para llenar campos por voz",
                        ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Campo Nombre
              _buildTextFieldWithSpeech(
                controller: _nombreController,
                label: 'Nombre completo *',
                hint: 'Ingrese su nombre completo',
                fieldName: 'Nombre completo',
                description: 'Requerido. Escriba su nombre y apellido',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese su nombre';
                  }
                  return null;
                },
              ),

              SizedBox(height: 15),

              // Campo Email - CON PROCESAMIENTO ESPECIAL
              _buildTextFieldWithSpeech(
                controller: _emailController,
                label: 'Correo electrónico *',
                hint: 'ejemplo@correo.com',
                fieldName: 'Correo electrónico',
                description:
                    'Requerido. Ingrese un email válido. Diga arroba para el símbolo @',
                keyboardType: TextInputType.emailAddress,
                isEmail: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese su email';
                  }
                  if (!value.contains('@')) {
                    return 'Ingrese un email válido';
                  }
                  return null;
                },
              ),

              SizedBox(height: 15),

                            // Campo País
              _buildPaisDropdown(),

              SizedBox(height: 15),

              // Campo Teléfono
              _buildTextFieldWithSpeech(
                controller: _telefonoController,
                label: 'Teléfono',
                hint: '+57 300 123 4567',
                fieldName: 'Teléfono',
                description: 'Opcional. Ingrese su número de contacto',
                keyboardType: TextInputType.phone,
              ),


              // Dropdown CON RECONOCIMIENTO DE VOZ
              _buildDropdownWithSpeech(),

              SizedBox(height: 15),

              // Campo Mensaje
              _buildTextFieldWithSpeech(
                controller: _mensajeController,
                label: 'Mensaje o comentarios',
                hint: 'Escriba su mensaje aquí...',
                fieldName: 'Mensaje',
                description: 'Opcional. Escriba cualquier comentario adicional',
                maxLines: 4,
              ),

              SizedBox(height: 20),

              // Checkbox términos
              _buildCheckboxWithSpeech(),

              SizedBox(height: 30),

              // Botones de acción CON VOZ
              _buildActionButtons(),

              SizedBox(height: 20),

              // Botón para leer todo el formulario
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => _readFormSummary(),
                  icon: Icon(Icons.audio_file),
                  label: Text('LEER RESUMEN DEL FORMULARIO'),
                ),
              ),
              
            ],
          ),
        ),
        
      ),
    ));
  }

  
  Widget _buildVolumeControls() {
  return Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 4, // Sombra ligera
    color: Colors.white,
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          

          Row(
            children: [
              Icon(Icons.volume_down, color: Colors.grey),
              SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.blue,
                    inactiveTrackColor: Colors.blue[100],
                    thumbColor: Colors.blue,
                    overlayColor: Colors.blue.withAlpha(32),
                    valueIndicatorColor: Colors.blue,
                  ),
                  child: Slider(
                    value: _ttsVolume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label: '${(_ttsVolume * 100).toInt()}%',
                    onChanged: _changeVolume,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.volume_up, color: Colors.grey),
            ],
          ),
          SizedBox(height: 5),
          Center(
            child: Text(
              'Volumen: ${(_ttsVolume * 100).toInt()}%',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildPaisDropdown() {
    bool isPaisListening = _isListening && _currentListeningField == 'país';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'País *',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(Icons.help_outline, size: 18),
              onPressed: () => _speak("Seleccione su país. Puede decirlo o elegir del menú"),
            ),
            IconButton(
              icon: Icon(
                isPaisListening ? Icons.stop : Icons.mic,
                size: 18,
                color: isPaisListening ? Colors.red : Colors.blue,
              ),
              onPressed: () async {
                // Iniciar reconocimiento de voz para país
                if (_isListening && _currentListeningField == 'país') {
                  await _stopListening();
                } else {
                  await _startFieldVoiceInput('País', _paisController);
                }
              },
            ),
          ],
        ),
        SizedBox(height: 5),
        DropdownButtonFormField<String>(
          value: _paisController.text.isNotEmpty ? _paisController.text : null,
          items: countryCodes.keys.map((pais) {
            return DropdownMenuItem(
              value: pais,
              child: Text(pais[0].toUpperCase() + pais.substring(1)), // Primera letra mayúscula
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _paisController.text = value;
                // Actualizar teléfono automáticamente
                String prefix = countryCodes[value]!;
                _telefonoController.text = prefix + ' ';
              });
              _speak("Seleccionado $value, prefijo agregado (_telefonoController.text)");
            }
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.all(12),
            enabledBorder: isPaisListening
                ? OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  )
                : null,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor seleccione su país';
            }
            return null;
          },
        ),
        if (isPaisListening) ...[
          SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.record_voice_over, size: 14, color: Colors.red),
              SizedBox(width: 5),
              Text(
                'Escuchando... diga su país',
                style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ],
    );
  }


  Widget _buildTextFieldWithSpeech({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String fieldName,
    required String description,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isEmail = false,
    String? Function(String?)? validator,
  }) {
    bool isThisFieldListening =
        _isListening && _currentListeningField == fieldName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            // Botón de ayuda (solo para leer descripción)
            IconButton(
              icon: Icon(Icons.help_outline, size: 18),
              onPressed: () => _readFieldDescription(fieldName, description),
              tooltip: 'Leer descripción del campo $fieldName',
            ),
            // Botón de micrófono
            IconButton(
              icon: Icon(
                isThisFieldListening ? Icons.stop : Icons.mic,
                size: 18,
                color: isThisFieldListening ? Colors.red : Colors.blue,
              ),
              onPressed:
                  () => _startFieldVoiceInput(
                    fieldName,
                    controller,
                    isEmail: isEmail,
                  ),
              tooltip:
                  isThisFieldListening
                      ? 'Detener grabación para $fieldName'
                      : 'Llenar $fieldName por voz',
            ),
          ],
        ),
        SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.all(12),
            enabledBorder:
                isThisFieldListening
                    ? OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2),
                    )
                    : null,
          ),
        ),
        if (isThisFieldListening) ...[
          SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.record_voice_over, size: 14, color: Colors.red),
              SizedBox(width: 5),
              Text(
                'Escuchando... Hable ahora',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDropdownWithSpeech() {
    bool isDropdownListening =
        _isListening && _currentListeningField == 'dropdown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Tipo de consulta *',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(Icons.help_outline, size: 18),
              onPressed:
                  () => _speak(
                    "Tipo de consulta. Seleccione una opción del menú desplegable. Diga opción uno, dos, tres o cuatro",
                  ),
              tooltip: 'Leer descripción del tipo de consulta',
            ),
            IconButton(
              icon: Icon(
                isDropdownListening ? Icons.stop : Icons.mic,
                size: 18,
                color: isDropdownListening ? Colors.red : Colors.blue,
              ),
              onPressed: _startDropdownVoiceInput,
              tooltip:
                  isDropdownListening
                      ? 'Detener selección por voz'
                      : 'Seleccionar opción por voz',
            ),
          ],
        ),
        SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            border:
                isDropdownListening
                    ? Border.all(color: Colors.red, width: 2)
                    : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedOption,
            items:
                ['Opción 1', 'Opción 2', 'Opción 3', 'Opción 4'].map((
                  String value,
                ) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedOption = newValue!;
              });
              _speak("Seleccionado: $newValue");
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ),
        if (isDropdownListening) ...[
          SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.record_voice_over, size: 14, color: Colors.red),
              SizedBox(width: 5),
              Text(
                'Escuchando... Diga opción uno, dos, tres o cuatro',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCheckboxWithSpeech() {
    return Row(
      children: [
        Checkbox(
          value: _aceptoTerminos,
          onChanged: (bool? value) {
            setState(() {
              _aceptoTerminos = value!;
            });
            _speak(value! ? "Términos aceptados" : "Términos no aceptados");
          },
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _aceptoTerminos = !_aceptoTerminos;
              });
              _speak(
                _aceptoTerminos
                    ? "Términos aceptados"
                    : "Términos no aceptados",
              );
            },
            child: Text(
              'Acepto los términos y condiciones *',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.help_outline, size: 18),
          onPressed:
              () => _speak(
                "Debe aceptar los términos y condiciones para continuar",
              ),
          tooltip: 'Leer descripción de términos y condiciones',
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    bool isSubmitListening = _isListening && _currentListeningField == 'submit';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration:
                    isSubmitListening
                        ? BoxDecoration(
                          border: Border.all(color: Colors.red, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        )
                        : null,
                child: ElevatedButton.icon(
                  onPressed: _submitForm,
                  icon: Icon(Icons.send),
                  label: Text('ENVIAR FORMULARIO'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ),
            SizedBox(width: 10),
            IconButton(
              icon: Icon(
                isSubmitListening ? Icons.stop : Icons.mic,
                size: 24,
                color: isSubmitListening ? Colors.red : Colors.green,
              ),
              onPressed: _startSubmitVoiceInput,
              tooltip:
                  isSubmitListening
                      ? 'Detener envío por voz'
                      : 'Enviar formulario por voz',
            ),
          ],
        ),
        if (isSubmitListening) ...[
          SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.record_voice_over, size: 14, color: Colors.red),
              SizedBox(width: 5),
              Text(
                'Escuchando... Diga "sí" para enviar o "no" para cancelar',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _readFormSummary() {
    String summary = """
      Resumen del formulario.
      Nombre: ${_nombreController.text.isEmpty ? 'No ingresado' : _nombreController.text}.
      Email: ${_emailController.text.isEmpty ? 'No ingresado' : _emailController.text}.
      Teléfono: ${_telefonoController.text.isEmpty ? 'No ingresado' : _telefonoController.text}.
      Tipo de consulta: $_selectedOption.
      Mensaje: ${_mensajeController.text.isEmpty ? 'No ingresado' : _mensajeController.text}.
      Términos: ${_aceptoTerminos ? 'Aceptados' : 'No aceptados'}.
    """;
    _speak(summary);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _mensajeController.dispose();
    flutterTts.stop();
    speechToText.stop();
    super.dispose();
  }
}