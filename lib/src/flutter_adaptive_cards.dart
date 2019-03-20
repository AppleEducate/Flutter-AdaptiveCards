library flutter_adaptive_cards;

import 'dart:async';
import 'package:flutter_adaptive_cards/src/action_handler.dart';
import 'package:flutter_adaptive_cards/src/registry.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_cards/src/elements/input.dart';
import 'package:flutter_adaptive_cards/src/utils.dart';
import 'package:http/http.dart' as http;

abstract class AdaptiveCardContentProvider {
  AdaptiveCardContentProvider({@required this.hostConfigPath});

  final String hostConfigPath;

  Future<Map> loadHostConfig() async {
    String hostConfigString = await rootBundle.loadString(hostConfigPath);
    return json.decode(hostConfigString);
  }

  Future<Map> loadAdaptiveCardContent();
}

class MemoryAdaptiveCardContentProvider extends AdaptiveCardContentProvider {
  MemoryAdaptiveCardContentProvider(
      {@required this.content, @required String hostConfigPath})
      : super(hostConfigPath: hostConfigPath);

  Map content;

  @override
  Future<Map> loadAdaptiveCardContent() {
    return Future.value(content);
  }
}

class AssetAdaptiveCardContentProvider extends AdaptiveCardContentProvider {
  AssetAdaptiveCardContentProvider(
      {@required this.path, @required String hostConfigPath})
      : super(hostConfigPath: hostConfigPath);

  String path;

  @override
  Future<Map> loadAdaptiveCardContent() async {
    return json.decode(await rootBundle.loadString(path));
  }
}

class NetworkAdaptiveCardContentProvider extends AdaptiveCardContentProvider {
  NetworkAdaptiveCardContentProvider(
      {@required this.url, @required String hostConfigPath})
      : super(hostConfigPath: hostConfigPath);

  String url;

  @override
  Future<Map> loadAdaptiveCardContent() async {
    return json.decode((await http.get(url)).body);
  }
}

class AdaptiveCard extends StatefulWidget {

  AdaptiveCard(
      {Key key, @required this.adaptiveCardContentProvider, this.placeholder,
      this.cardRegistry = const CardRegistry(), this.onSubmit, this.onOpenUrl, this.showDebugJson = true})
      : super(key: key);

  AdaptiveCard.network({
    Key key,
    this.placeholder,
    this.cardRegistry,
    @required String url,
    @required String hostConfigPath,
    this.onSubmit,
    this.onOpenUrl,
    this.showDebugJson = true,
  }) : adaptiveCardContentProvider = NetworkAdaptiveCardContentProvider(
            url: url, hostConfigPath: hostConfigPath);

  AdaptiveCard.asset({
    Key key,
    this.placeholder,
    this.cardRegistry,
    @required String assetPath,
    @required String hostConfigPath,
    this.onSubmit,
    this.onOpenUrl,
    this.showDebugJson = true,
  }) : adaptiveCardContentProvider = AssetAdaptiveCardContentProvider(
            path: assetPath, hostConfigPath: hostConfigPath);

  AdaptiveCard.memory({
    Key key,
    this.placeholder,
    this.cardRegistry,
    @required Map content,
    @required String hostConfigPath,
    this.onSubmit,
    this.onOpenUrl,
    this.showDebugJson = true,
  }) : adaptiveCardContentProvider = MemoryAdaptiveCardContentProvider(
            content: content, hostConfigPath: hostConfigPath);

  final AdaptiveCardContentProvider adaptiveCardContentProvider;

  final Widget placeholder;

  final CardRegistry cardRegistry;

  final Function(Map map) onSubmit;
  final Function(String url) onOpenUrl;
  final bool showDebugJson;

  @override
  _AdaptiveCardState createState() => new _AdaptiveCardState();
}

class _AdaptiveCardState extends State<AdaptiveCard> {
  Map map;
  Map hostConfig;


  CardRegistry cardRegistry;



  Function(Map map) onSubmit;
  Function(String url) onOpenUrl;


  @override
  void initState() {
    super.initState();
    widget.adaptiveCardContentProvider.loadHostConfig().then((hostConfigMap) {
      setState(() {
        hostConfig = hostConfigMap;
      });
    });
    widget.adaptiveCardContentProvider
        .loadAdaptiveCardContent()
        .then((adaptiveMap) {
      setState(() {
        map = adaptiveMap;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if(widget.cardRegistry != null) {
      cardRegistry = widget.cardRegistry;
    } else {
      CardRegistry cardRegistry = DefaultCardRegistry.of(context);
      if(cardRegistry != null) {
        this.cardRegistry = cardRegistry;
      } else {
        this.cardRegistry = const CardRegistry();
      }
    }


    if(widget.onSubmit != null) {
      onSubmit = widget.onSubmit;
    } else {
      var foundOnSubmit = DefaultAdaptiveCardHandlers.of(context).onSubmit;
      if(foundOnSubmit != null) {
        onSubmit = foundOnSubmit;
      } else {
        onSubmit = (it) {
          Scaffold.of(context).showSnackBar(SnackBar(
              content: Text("No handler found for: \n" + it.toString())));
        };
      }
    }

    if(widget.onOpenUrl != null) {
      onOpenUrl = widget.onOpenUrl;
    } else {
      var foundOpenUrl = DefaultAdaptiveCardHandlers.of(context).onOpenUrl;
      if(foundOpenUrl  != null) {
        onOpenUrl = foundOpenUrl;
      } else {
        onOpenUrl = (it) {
          Scaffold.of(context).showSnackBar(SnackBar(
              content: Text("No handler found for: \n" + it.toString())));
        };
      }
    }

  }

  @override
  Widget build(BuildContext context) {
    if (map == null || hostConfig == null) {
      return widget.placeholder ?? const SizedBox();
    }
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: RawAdaptiveCard.fromMap(map, hostConfig,
        cardRegistry: cardRegistry,
        onOpenUrl: onOpenUrl,
        onSubmit: onSubmit,
        showDebugJson: widget.showDebugJson,
      ),
    );
  }
}



/// Main entry point to adaptive cards.
///
/// This widget takes a [map] (which usually is just a json decoded string) and
/// displays in natively. Additionally a host config needs to be provided for
/// styling.
class RawAdaptiveCard extends StatefulWidget {
  RawAdaptiveCard.fromMap(this.map, this.hostConfig, {
    this.cardRegistry = const CardRegistry(),
    @required this.onSubmit,
    @required this.onOpenUrl,
    this.showDebugJson = true,
  });

  final Map map;
  final Map hostConfig;
  final CardRegistry cardRegistry;

  final Function(Map map) onSubmit;
  final Function(String url) onOpenUrl;

  final bool showDebugJson;

  @override
  RawAdaptiveCardState createState() => RawAdaptiveCardState();
}

class RawAdaptiveCardState extends State<RawAdaptiveCard> {
  // Wrapper around the host config
  ReferenceResolver resolver;
  UUIDGenerator idGenerator;
  CardRegistry cardRegistry;

  // The root element
  AdaptiveElement _adaptiveElement;

  List<VoidCallback> deactivateListeners = [];

  @override
  void initState() {
    super.initState();
    resolver = ReferenceResolver(widget.hostConfig);
    idGenerator = UUIDGenerator();
    cardRegistry = widget.cardRegistry;

    _adaptiveElement =
        widget.cardRegistry.getElement(widget.map, this);
  }

  /// Every widget can access method of this class, meaning setting the state
  /// is possible from every element
  void rebuild() {
    setState(() {});
  }

  void addDeactivateListener(VoidCallback callback) {
    deactivateListeners.add(callback);
  }

  @override
  void deactivate() {
    super.deactivate();
    deactivateListeners.forEach((it) => it());
  }

  /// Submits all the inputs of this adaptive card, does it by recursively
  /// visiting the elements in the tree
  void submit(Map map) {
    _adaptiveElement.visitChildren((element) {
      if (element is AdaptiveInput) {
        element.appendInput(map);
      }
    });
    widget.onSubmit(map);
  }

  void openUrl(String url) {
    widget.onOpenUrl(url);
  }

  void showError(String message) {
    Scaffold.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// min and max dates may be null, in this case no constraint is made in that direction
  Future<DateTime> pickDate(DateTime min, DateTime max) {
    DateTime initialDate = DateTime.now();
    return showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: min ?? DateTime.now().subtract(Duration(days: 10000)),
        lastDate: max ?? DateTime.now().add(Duration(days: 10000)));
  }

  Future<TimeOfDay> pickTime() {
    TimeOfDay initialTimeOfDay = TimeOfDay.now();
    return showTimePicker(context: context, initialTime: initialTimeOfDay);
  }

  @override
  Widget build(BuildContext context) {
    Widget child = _adaptiveElement.generateWidget();

    assert(() {
      if(widget.showDebugJson) {
        JsonEncoder encoder = new JsonEncoder.withIndent('  ');
        String prettyprint = encoder.convert(widget.map);
        child = Column(
          children: <Widget>[
            FlatButton(
              textColor: Colors.indigo,
              onPressed: () {
                showDialog(context: context, builder: (context) {
                  return AlertDialog(
                    title: Text("JSON (only added in debug mode, you can also turn"
                        "it of manually by passing showDebugJson = false)"),
                    content: SingleChildScrollView(child: Text(prettyprint)),
                    actions: <Widget>[
                      Center(
                        child: FlatButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text("Thanks"),
                        ),
                      )
                    ],
                    contentPadding: EdgeInsets.all(8.0),
                  );
                });
              },
              child: Text("Debug show the JSON"),
            ),
            child,
          ],
        );
      }
      return true;
    }());
    return Card(
      child: child,
    );
  }
}

/// The visitor, the function is called once for every element in the tree
typedef AdaptiveElementVisitor = void Function(AdaptiveElement element);

/// The base class for every element (widget) drawn on the screen.
///
/// The lifecycle is as follows:
/// - [loadTree()] is called, all the initialization should be done here
/// - [generateWidget()] is called every time the elements needs to render
/// this method should be as lightweight as possible because it could possibly
/// be called many times (for example in an animation). The method should also be
/// idempotent meaning calling it multiple times without changing anything should
/// return the same result
///
/// This class also holds some references every element needs.
/// --------------------------------------------------------------------
/// The [adaptiveMap] is the map associated with that element
///
/// root
/// |
/// currentElement <-- ([adaptiveMap] contains the subtree from there)
/// |       |
/// child 1 child2
/// --------------------------------------------------------------------
///
/// The [resolver] is a handy wrapper around the hostConfig, which makes accessing
/// it easier.
///
/// The [widgetState] provides access to flutter specific implementations.
///
/// If the element has children (you don't need to do this if the element is a
/// leaf):
/// implement the method [visitChildren] and call visitor(this) in addition call
/// [visitChildren] on each child with the passed visitor.
abstract class AdaptiveElement {
  AdaptiveElement(
      {@required this.adaptiveMap,
      @required this.widgetState}) {
    loadTree();
  }

  final Map adaptiveMap;

  String id;

  /// Because some widgets (looking at you ShowCardAction) need to set the state
  /// all elements get a way to set the state.
  final RawAdaptiveCardState widgetState;

  /// This method should be implemented by the actual elements to return
  /// their Flutter representation.
  Widget build();

  /// Use this method to obtain the widget tree of the adaptive card.
  ///
  /// Each mixin has the opportunity to add something to the widget hierarchy.
  ///
  /// An example:
  /// @override
  /// Widget generateWidget() {
  ///  assert(separator != null, "Did you forget to call loadSeperator in this class?");
  ///  return Column(
  ///    children: <Widget>[
  ///      separator? Divider(height: topSpacing,): SizedBox(height: topSpacing,),
  ///      super.generateWidget(),
  ///    ],
  ///  );
  ///}
  ///
  /// This works because each mixin calls [generateWidget] in its generateWidget
  /// and adds the returned value into the widget tree. Eventually the base
  /// implementation (this) will be called and the elements actual build method is
  /// included.
  @mustCallSuper
  Widget generateWidget() {
    return build();
  }

  void loadId() {
    if (adaptiveMap.containsKey("id")) {
      id = adaptiveMap["id"];
    } else {
      id = widgetState.idGenerator.getId();
    }
  }

  @mustCallSuper
  void loadTree() {
    loadId();
  }

  /// Visits the children
  void visitChildren(AdaptiveElementVisitor visitor) {
    visitor(this);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdaptiveElement &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}







/// Resolves values based on the host config.
///
/// All values can also be null, in that case the default is used
class ReferenceResolver {
  ReferenceResolver(this.hostConfig);

  final Map hostConfig;

  String _currentStyle;

  dynamic resolve(String key, String value) {
    dynamic res =  hostConfig[key][firstCharacterToLowerCase(value)];
    assert(res != null, "Could not find hostConfig[$key][${firstCharacterToLowerCase(value)}]");
    return res;
  }

  dynamic get(String key) {
    dynamic res =  hostConfig[key];
    assert(res != null, "Could not find hostConfig[$key]");
    return res;
  }

  FontWeight resolveFontWeight(String value) {
    int weight = resolve("fontWeights", value ?? "default");
    assert(
        weight != null,
        "\n"
        "FontWeight '${value ?? "default"}' was not found in the host_config. \n\n"
        "The available font weights were: \n\n"
        "${(hostConfig["fontWeights"] as Map).entries.map((entry) => "${entry.key}: ${entry.value}\n").toList()}");
    FontWeight fontWeight = FontWeight.values.firstWhere(
        (possibleWeight) => possibleWeight.toString() == "FontWeight.w$weight");
    assert(fontWeight != null, "There is no FontWight.w$weight");
    return fontWeight;
  }

  double resolveFontSize(String value) {
    int size = resolve("fontSizes", value ?? "default");
    assert(
        size != null,
        "\n"
        "Fontsize '${value ?? "default"}' was not found in the host_config. \n\n"
        "The available font sizes were: \n\n"
        "${(hostConfig["fontSizes"] as Map).entries.map((entry) => "${entry.key}: ${entry.value}\n").toList()}");
    return size.toDouble();
  }

  /// Resolves a color from the host config
  ///
  /// Typically one of the following colors:
  /// - default
  /// - dark
  /// - light
  /// - accent
  /// - good
  /// - warning
  /// - attention
  Color resolveColor(String color, bool isSubtle) {
    String myColor = color ?? "default";
    String subtleOrDefault = isSubtle ?? false ? "subtle" : "default";
    _currentStyle = _currentStyle ?? "default";
    // Make it case insensitive
    String colorValue = hostConfig["containerStyles"][_currentStyle]
            ["foregroundColors"][firstCharacterToLowerCase(myColor)]
        [subtleOrDefault];
    return parseColor(colorValue);
  }

  /// This is to correctly resolve corresponding styles in a container
  ///
  /// Before a container loads its children it first needs to set its style here
  /// IMPORTANT, is needs to be called after every child iteration because a container down the tree might have
  /// overwritten it for its portion
  void setContainerStyle(String style) {
    assert(style == null || style == "default" || style == "emphasis");
    String myStyle = style ?? "default";
    _currentStyle = myStyle;
  }

  double resolveSpacing(String spacing) {
    String mySpacing = spacing ?? "default";
    if (mySpacing == "none") return 0.0;
    int intSpacing = hostConfig["spacing"][firstCharacterToLowerCase(mySpacing)];
    assert(intSpacing != null, "hostConfig[\"spacing\"][\"${firstCharacterToLowerCase(mySpacing)}\"] was null");
    return intSpacing.toDouble();
  }
}




class UUIDGenerator {

  UUIDGenerator(): uuid = Uuid();

  final Uuid uuid;

  String getId() {
   return uuid.v1();
  }
}

