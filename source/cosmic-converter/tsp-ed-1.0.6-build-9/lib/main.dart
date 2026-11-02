// Block One ///////////////////////////////////////////////////
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'conversion_engine.dart';
import 'widgets/frog_widget.dart';
import 'widgets/dialog_queue.dart';
import 'widgets/easter_eggs.dart';
import 'widgets/frog_idle_animator.dart';
import 'widgets/frog_heart_button.dart';
import 'widgets/privacy_policy_button.dart';
import 'widgets/cosmic_star_field.dart';
import 'widgets/cosmic_rainbow_title.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const CosmicConverterApp());
}

class CosmicConverterApp extends StatelessWidget {
  const CosmicConverterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cosmic Converter',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          labelStyle: TextStyle(fontSize: 19),
          floatingLabelStyle: TextStyle(fontSize: 19, color: Colors.tealAccent),
        ),
      ),
      home: const ConverterHomePage(),
    );
  }
}

class ConverterHomePage extends StatefulWidget {
  const ConverterHomePage({super.key});

  @override
  State<ConverterHomePage> createState() => _ConverterHomePageState();
}

class _ConverterHomePageState extends State<ConverterHomePage> {
  // Frog controller
  final GlobalKey<FrogWidgetState> frogKey = GlobalKey<FrogWidgetState>();
  final GlobalKey<FrogIdleAnimatorState> frogIdleAnimatorKey =
      GlobalKey<FrogIdleAnimatorState>();

  // Input field controller
  final TextEditingController inputController = TextEditingController();
  final FocusNode amountFocusNode = FocusNode();

  // Cosmic mode toggle
  bool cosmicMode = false;

  // Category selection
  String? selectedCategory;

  // Unit selections
  String? fromUnit;
  String? toUnit;

  // Input + result
  String inputText = "";
  double? resultValue;
  String? inputError;
  String? conversionError;
  String? guidance;

  // ⭐ One-time water-density popup flag
  bool hasShownWaterWarning = false;

  // ⭐ One-time 30-day month popup flag
  bool hasShownMonthWarning = false;

  // Tracks whether the current input is below absolute zero.
  bool isBelowAbsoluteZero = false;

  // Block Two ////////////////////////////////////////////////////////////////
  // Trigger conversion whenever inputs change
  void _attemptConversion() {
    final trimmedInput = inputText.trim();

    if (trimmedInput.isEmpty) {
      setState(() {
        resultValue = null;
        inputError = null;
        conversionError = null;
        isBelowAbsoluteZero = false;
        guidance = selectedCategory == null
            ? 'Choose a category to begin.'
            : fromUnit == null
            ? 'Choose the starting unit.'
            : toUnit == null
            ? 'Choose the unit to convert to.'
            : 'Enter an amount to convert.';
      });
      return;
    }

    final isIncompleteNumber =
        trimmedInput == '-' ||
        trimmedInput == '+' ||
        trimmedInput == '.' ||
        trimmedInput == '-.' ||
        trimmedInput == '+.';

    if (isIncompleteNumber) {
      setState(() {
        resultValue = null;
        inputError = null;
        conversionError = null;
        isBelowAbsoluteZero = false;
        guidance = 'Finish entering the number, then the answer will appear.';
      });
      return;
    }

    final value = double.tryParse(trimmedInput);

    if (value == null || value.isNaN) {
      setState(() {
        resultValue = null;
        inputError =
            "The frog says try a number, decimal point, or negative sign. "
            "And Ribbit. The frog says Ribbit.";
        conversionError = null;
        isBelowAbsoluteZero = false;
        guidance = 'Use a number, such as 12, 3.5, or -4.';
      });
      return;
    }

    if (value.isInfinite) {
      setState(() {
        resultValue = null;
        inputError =
            "That number is too large for this universe, and my brain... Try a smaller number.";
        conversionError = null;
        isBelowAbsoluteZero = false;
        guidance = null;
      });
      return;
    }

    if (fromUnit == null || toUnit == null) {
      setState(() {
        resultValue = null;
        inputError = null;
        conversionError = null;
        isBelowAbsoluteZero = false;
        guidance = fromUnit == null
            ? 'Choose the starting unit.'
            : 'Choose the unit to convert to.';
      });
      return;
    }

    inputError = null;
    guidance = null;

    final canonicalFrom = canonicalizeUnit(fromUnit!);
    final canonicalTo = canonicalizeUnit(toUnit!);

    // ------------------------------------------------------------
    // ONE-TIME WATER-DENSITY POPUP TRIGGER
    // ------------------------------------------------------------
    final fromCat = detectCategory(canonicalFrom);
    final toCat = detectCategory(canonicalTo);

    // ------------------------------------------------------------
    // BELOW-ABSOLUTE-ZERO EASTER EGG
    // ------------------------------------------------------------
    if (fromCat == 'temperature') {
      double temperatureInKelvin;

      switch (canonicalFrom) {
        case 'celsius':
          temperatureInKelvin = value + 273.15;
          break;
        case 'fahrenheit':
          temperatureInKelvin = (value - 32) * 5 / 9 + 273.15;
          break;
        case 'kelvin':
          temperatureInKelvin = value;
          break;
        case 'planck_temperature':
          temperatureInKelvin = value * 1.416784e32;
          break;
        default:
          temperatureInKelvin = 0;
      }

      if (temperatureInKelvin < 0) {
        setState(() {
          resultValue = null;
          conversionError =
              'That temperature is below absolute zero. Choose a value at or above absolute zero.';
          guidance = 'Adjust the temperature, then try again.';
        });

        if (!isBelowAbsoluteZero) {
          isBelowAbsoluteZero = true;
          frogKey.currentState?.setFrozen(true);

          DialogQueue.instance.enqueue(
            context: context,
            builder: (context) => const CosmicDialog(
              title: "Beyond Absolute Zero",
              message:
                  "Even the cosmos has limits. This temperature has fallen "
                  "below absolute zero, where ordinary physics refuses to follow.",
            ),
            onDismissed: () {
              frogKey.currentState?.setFrozen(false);
            },
          );
        }

        return;
      }
    }

    isBelowAbsoluteZero = false;

    final isCrossCategory =
        (fromCat == 'volume' && toCat == 'weight') ||
        (fromCat == 'weight' && toCat == 'volume');

    if (isCrossCategory && !hasShownWaterWarning) {
      hasShownWaterWarning = true;
    }

    // ------------------------------------------------------------
    // ONE-TIME 30-DAY MONTH POPUP TRIGGER
    // ------------------------------------------------------------
    final usesMonth = canonicalFrom == 'month' || canonicalTo == 'month';

    if (usesMonth && !hasShownMonthWarning) {
      hasShownMonthWarning = true;
    }

    // ------------------------------------------------------------
    // Perform conversion using canonical units
    // ------------------------------------------------------------
    final result = convertValue(value, canonicalFrom, canonicalTo);

    if (result == null) {
      setState(() {
        resultValue = null;
        inputError = null;
        conversionError =
            "The stars did not align, and this answer was sucked into the "
            "black hole of oblivion. Check both units and try again.";
        guidance = 'Choose compatible units, then try again.';
      });
      return;
    }

    if (!result.isFinite) {
      setState(() {
        resultValue = null;
        inputError =
            "That number is too large for this universe, and my brain... Try a smaller number.";
        conversionError = null;
        guidance = null;
      });
      return;
    }

    setState(() {
      resultValue = result;
      inputError = null;
      conversionError = null;
      guidance = null;
    });

    // ------------------------------------------------------------
    // Easter egg engine (already normalized inside)
    // ------------------------------------------------------------
    checkEasterEggs(
      context: context,
      frog: frogKey.currentState,
      fromUnit: canonicalFrom,
      toUnit: canonicalTo,
      inputValue: value,
      resultValue: result,
    );
  }

  // Block Three//////////////////////////////////////////////////////////////////////////////
  // Conversion calculations now live in conversion_engine.dart.

  // Block Four/////////////////////////////////////////////////////////////////////////////
  // ------------------------------------------------------------
  // UI BUILD
  // ------------------------------------------------------------

  // ------------------------------------------------------------
  // CLEAN UP TEXT FIELD CONTROLLER
  // ------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    amountFocusNode.addListener(() {
      if (amountFocusNode.hasFocus) {
        frogIdleAnimatorKey.currentState?.pauseForSpecialReaction();
      } else {
        frogIdleAnimatorKey.currentState?.resumeAfterSpecialReaction();
      }
    });
  }

  @override
  void dispose() {
    amountFocusNode.dispose();
    inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    // Keeps the frog beside the title instead of sitting on top of it.
    final double frogLeft = screenWidth < 360 ? -24 : -12;
    final double titleSpacing = screenWidth < 360 ? 76 : 92;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // ------------------------------------------------------------
          // COSMIC MODE STAR FIELD (always behind the interface)
          // ------------------------------------------------------------
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: cosmicMode
                    ? const CosmicStarField(key: ValueKey("cosmic-stars"))
                    : const SizedBox.expand(key: ValueKey("no-cosmic-stars")),
              ),
            ),
          ),

          // ------------------------------------------------------------
          // MAIN UI (AppBar + content)
          // ------------------------------------------------------------
          SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                PreferredSize(
                  preferredSize: const Size.fromHeight(90),
                  child: AppBar(
                    automaticallyImplyLeading: false,
                    systemOverlayStyle: const SystemUiOverlayStyle(
                      statusBarIconBrightness: Brightness.light,
                      systemNavigationBarIconBrightness: Brightness.light,
                    ),
                    backgroundColor: Colors.transparent,
                    titleSpacing: titleSpacing,
                    flexibleSpace: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: cosmicMode
                              ? const [Color(0xCC2A0A4A), Color(0xCC0A1A4A)]
                              : const [Color(0xFF2A0A4A), Color(0xFF0A1A4A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    title: CosmicRainbowTitle(
                      text: "Cosmic Converter",
                      enabled: cosmicMode,
                    ),
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.paddingOf(context).bottom + 80,
                      ),
                      child: _buildMainColumn(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ------------------------------------------------------------
          // FROG FLOATING ABOVE EVERYTHING
          // ------------------------------------------------------------
          Positioned(
            // Center the 40px mascot in the toolbar, accounting for both
            // 20px tap-padding layers around it.
            top:
                MediaQuery.paddingOf(context).top +
                (kToolbarHeight - 40) / 2 -
                40,
            left: MediaQuery.paddingOf(context).left + frogLeft,
            child: FrogIdleAnimator(
              key: frogIdleAnimatorKey,
              frogKey: frogKey,
              child: Padding(
                padding: const EdgeInsets.all(20), // ⭐ bigger tap area
                child: FrogWidget(
                  key: frogKey,
                  cosmicMode: cosmicMode,
                  onSpecialReactionStarted: () {
                    frogIdleAnimatorKey.currentState?.pauseForSpecialReaction();
                  },
                  onSpecialReactionEnded: () {
                    frogIdleAnimatorKey.currentState
                        ?.resumeAfterSpecialReaction();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: cosmicMode
                          ? "Turn Cosmic Mode off"
                          : "Turn Cosmic Mode on",
                      icon: Icon(
                        cosmicMode
                            ? Icons.auto_awesome
                            : Icons.auto_awesome_outlined,
                        color: Colors.tealAccent,
                      ),
                      onPressed: () {
                        setState(() => cosmicMode = !cosmicMode);
                      },
                    ),
                    const Text(
                      "COSMIC MODE",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PrivacyPolicyButton(),
                    Text(
                      "PRIVACY POLICY",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FrogHeartButton(),
                    Text(
                      "SEND ME A COFFEE",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Extracted for clarity — your original Column content goes here
  Widget _buildMainColumn() {
    final availableUnits = availableUnitsForCategory(selectedCategory);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CATEGORY DROPDOWN
        DropdownButtonFormField<String>(
          initialValue: selectedCategory,
          isExpanded: true,
          style: const TextStyle(fontSize: 19),
          decoration: const InputDecoration(
            labelText: "Category",
            border: OutlineInputBorder(),
          ),
          items: categories
              .map(
                (c) =>
                    DropdownMenuItem(value: c, child: Text(displayCategory(c))),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              selectedCategory = value;

              // FULL RESET ON CATEGORY CHANGE
              fromUnit = null;
              toUnit = null;
              inputText = "";
              resultValue = null;
              inputError = null;
              conversionError = null;
              guidance = 'Choose the starting unit.';
              isBelowAbsoluteZero = false;

              // Clear visible input field too
              inputController.clear();

              // Optional: reset frog expressions
              frogKey.currentState?.neutralize();
            });
          },
        ),

        const SizedBox(height: 20),

        // FROM UNIT
        DropdownButtonFormField<String>(
          initialValue: fromUnit,
          isExpanded: true,
          style: const TextStyle(fontSize: 19),
          decoration: const InputDecoration(
            labelText: "From (Starting Measurement)",
            border: OutlineInputBorder(),
          ),
          items: availableUnits
              .map(
                (u) => DropdownMenuItem(value: u, child: Text(displayUnit(u))),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              fromUnit = value;
            });
            _attemptConversion();
          },
        ),
        const SizedBox(height: 20),

        // INPUT FIELD
        TextField(
          controller: inputController,
          focusNode: amountFocusNode,
          style: const TextStyle(fontSize: 19),
          decoration: InputDecoration(
            labelText: "How Much Do You Have?",
            border: const OutlineInputBorder(),
            errorText: inputError,
          ),
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          onChanged: (value) {
            setState(() => inputText = value);
            _attemptConversion();
          },
        ),
        const SizedBox(height: 20),

        // TO UNIT
        DropdownButtonFormField<String>(
          initialValue: toUnit,
          isExpanded: true,
          style: const TextStyle(fontSize: 19),
          decoration: const InputDecoration(
            labelText: "To (What You Want To Know)",
            border: OutlineInputBorder(),
          ),
          items: availableUnits
              .map(
                (u) => DropdownMenuItem(value: u, child: Text(displayUnit(u))),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              toUnit = value;
            });
            _attemptConversion();
          },
        ),
        const SizedBox(height: 20),

        if (guidance != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              guidance!,
              style: const TextStyle(color: Colors.tealAccent, fontSize: 17),
            ),
          ),

        // RESULT CARD
        if (resultValue != null)
          Card(
            elevation: 4,
            color: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.tealAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "$inputText ${displayUnit(fromUnit!)} = "
                      "${resultValue!.toStringAsPrecision(8)} "
                      "${displayUnit(toUnit!)}",
                      style: const TextStyle(fontSize: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (resultValue != null && usesFixedThirtyDayMonth(fromUnit, toUnit))
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'This conversion uses a fixed 30-day month.',
              style: TextStyle(color: Colors.tealAccent),
            ),
          ),
        if (resultValue != null && isWeightVolumeCategory(selectedCategory))
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Weight and volume conversions assume the material is water.',
              style: TextStyle(color: Colors.tealAccent),
            ),
          ),
        if (conversionError != null)
          Text(
            conversionError!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 17),
          ),
      ],
    );
  }
}
