import 'dart:async';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:orchid/api/orchid_api.dart';
import 'package:orchid/api/orchid_crypto.dart';
import 'package:orchid/api/orchid_eth.dart';
import 'package:orchid/api/orchid_pricing.dart';
import 'package:orchid/api/orchid_types.dart';
import 'package:orchid/api/preferences/user_preferences.dart';
import 'package:orchid/api/purchase/orchid_purchase.dart';
import 'package:orchid/generated/l10n.dart';
import 'package:orchid/pages/circuit/openvpn_hop_page.dart';
import 'package:orchid/pages/circuit/orchid_hop_page.dart';
import 'package:orchid/pages/common/app_reorderable_list.dart';
import 'package:orchid/pages/common/dialogs.dart';
import 'package:orchid/pages/common/formatting.dart';
import 'package:orchid/pages/common/wrapped_switch.dart';
import 'package:orchid/pages/onboarding/legacy_welcome_dialog.dart';
import 'package:orchid/pages/onboarding/welcome_dialog.dart';
import 'package:orchid/pages/purchase/purchase_page.dart';
import 'package:orchid/util/collections.dart';

import '../app_gradients.dart';
import '../app_text.dart';
import '../app_transitions.dart';
import 'add_hop_page.dart';
import 'hop_editor.dart';
import 'hop_tile.dart';
import 'model/circuit.dart';
import 'model/circuit_hop.dart';
import 'model/orchid_hop.dart';

class CircuitPage extends StatefulWidget {
  final WrappedSwitchController switchController;

  CircuitPage({Key key, this.switchController}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return new CircuitPageState();
  }
}

// TODO: This class has gotten pretty big. Time for some refactoring!
class CircuitPageState extends State<CircuitPage>
    with TickerProviderStateMixin {
  List<StreamSubscription> _rxSubs = List();
  List<UniqueHop> _hops;

  // Master timeline for connect animation
  AnimationController _masterConnectAnimController;

  // The duck into hole animation
  AnimationController _bunnyDuckAnimController;

  // Animations driven by the master timelines
  Animation<double> _connectAnimController;
  Animation<double> _bunnyExitAnim;
  Animation<double> _bunnyDuckAnimation;
  Animation<double> _bunnyEnterAnim;
  Animation<double> _holeTransformAnim;
  Animation<Color> _hopColorTween;

  // Anim params
  int _fadeAnimTime = 200;
  int _connectAnimTime = 1200;
  DateTime _lastInteractionTime;
  Timer _bunnyDuckTimer;

  bool vpnSwitchInstructionsViewed = false;
  bool _dialogInProgress = false;

  @override
  void initState() {
    super.initState();
    // Test Localization
    //S.load(Locale('zh', 'CN'));
    initStateAsync();
    initAnimations();
  }

  Timer _checkBalancesTimer;

  void initStateAsync() async {
    // Hook up to the provided vpn switch
    widget.switchController.onChange = _connectSwitchChanged;

    // Set the initial state of the vpn switch based on the user pref.
    // Note: By design the switch on this page does not track or respond to the
    // Note: dynamic connection state but instead reflects the user pref.
    // Note: See `monitoring_page.dart` or `connect_page` for controls that track the
    // Note: system connection status.
    _switchOn = await UserPreferences().getDesiredVPNState();

    vpnSwitchInstructionsViewed =
        await UserPreferences().getVPNSwitchInstructionsViewed();

    OrchidAPI().circuitConfigurationChanged.listen((_) {
      _updateCircuit();
    });

    _checkFirstLaunch();
    _checkBalancesTimer =
        Timer.periodic(Duration(seconds: 30), _checkOrchidHopAlerts);
  }

  Map<UniqueHop, bool> _showHopAlert = Map();

  /// Check each Orchid Hop's lottery pot for alert conditions.
  void _checkOrchidHopAlerts(timer) async {
    if (_hops == null) {
      return;
    }
    // Check for hops that cannot write tickets.
    List<StoredEthereumKey> keys = await UserPreferences().getKeys();
    for (var uniqueHop in _hops) {
      CircuitHop hop = uniqueHop.hop;
      if (hop is OrchidHop) {
        var pot =
            await OrchidEthereum.getLotteryPot(hop.funder, hop.getSigner(keys));
        var ticketValue = await OrchidPricingAPI().getMaxTicketValue(pot);
        _showHopAlert[uniqueHop] = ticketValue.value <= 0;
      }
    }
    setState(() {});
  }

  void _checkFirstLaunch() async {
    if (!await UserPreferences().getFirstLaunchInstructionsViewed()) {
      _showWelcomeDialog();
      UserPreferences().setFirstLaunchInstructionsViewed(true);
    }
  }

  void _updateCircuit() async {
    var circuit = await UserPreferences().getCircuit();
    if (mounted) {
      setState(() {
        var keyBase = DateTime.now().millisecondsSinceEpoch;
        // Wrap the hops with a locally unique id for the UI
        _hops = mapIndexed(circuit?.hops ?? [], ((index, hop) {
          var key = keyBase + index;
          return UniqueHop(key: key, hop: hop);
        })).toList();
      });

      // Set the correct animation states for the connection status
      // Note: We cannot properly do this until we know if we have hops!
      print("init state, setting initial connection state");
      _connectionStateChanged(OrchidAPI().connectionStatus.value,
          animated: false);
    }
    _checkOrchidHopAlerts(null); // refresh alert status
  }

  void initAnimations() {
    _masterConnectAnimController = AnimationController(
        duration: Duration(milliseconds: _connectAnimTime), vsync: this);

    _bunnyDuckAnimController =
        AnimationController(duration: Duration(milliseconds: 300), vsync: this);

    _connectAnimController = CurvedAnimation(
        parent: _masterConnectAnimController, curve: Interval(0, 1.0));

    _bunnyExitAnim = CurvedAnimation(
        parent: _connectAnimController,
        curve: Interval(0, 0.4, curve: Curves.easeInOutExpo));

    _bunnyDuckAnimation = CurvedAnimation(
        parent: _bunnyDuckAnimController, curve: Curves.easeOut);

    _holeTransformAnim = CurvedAnimation(
        parent: _connectAnimController,
        curve: Interval(0.4, 0.5, curve: Curves.easeIn));

    _bunnyEnterAnim = CurvedAnimation(
        parent: _connectAnimController,
        curve: Interval(0.6, 1.0, curve: Curves.easeInOutExpo));

    _hopColorTween =
        ColorTween(begin: Color(0xffa29ec0), end: Color(0xff8c61e1))
            .animate(_connectAnimController);

    _bunnyDuckTimer = Timer.periodic(Duration(seconds: 1), _checkBunny);

    // Update the UI on connection status changes
    _rxSubs.add(OrchidAPI().connectionStatus.listen(_connectionStateChanged));
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody();
  }

  Widget _buildBody() {
    return NotificationListener(
      onNotification: (notif) {
        _userInteraction();
        return false;
      },
      child: GestureDetector(
        onTapDown: (_) {
          _userInteraction();
        },
        child: Container(
          decoration: BoxDecoration(gradient: AppGradients.basicGradient),
          child: Visibility(
            visible: _hops != null,
            replacement: Container(),
            child: AnimatedBuilder(
                animation: Listenable.merge(
                    [_connectAnimController, _bunnyDuckAnimation]),
                builder: (BuildContext context, Widget child) {
                  return _buildHopList();
                }),
          ),
        ),
      ),
    );
  }

  bool _showEnableVPNInstruction() {
    // Note: this instruction follows the switch, not the connected status
    return !vpnSwitchInstructionsViewed && _hasHops() && !_switchOn;
  }

  Widget _buildHopList() {
    return Column(
      children: <Widget>[
        Expanded(
          child: AppReorderableListView(
              header: Column(
                children: <Widget>[
                  AnimatedCrossFade(
                    duration: Duration(milliseconds: _fadeAnimTime),
                    crossFadeState: _showEnableVPNInstruction()
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: _buildEnableVPNInstruction(),
                    secondChild: pady(16),
                  ),
                  _buildStartTile(),
                  _buildStatusTile(),
                  HopTile.buildFlowDivider(),
                ],
              ),
              children: (_hops ?? []).map((uniqueHop) {
                return _buildDismissableHopTile(uniqueHop);
              }).toList(),
              footer: Column(
                children: <Widget>[
                  _buildNewHopTile(),
                  if (!_hasHops()) _buildFirstHopInstruction(),
                  HopTile.buildFlowDivider(
                      padding: EdgeInsets.only(
                          top: _hasHops() ? 16 : 2, bottom: 10)),
                  _buildEndTile(),
                ],
              ),
              onReorder: _onReorder),
        ),
      ],
    );
  }

  // The starting (top) tile in the hop flow
  Widget _buildStartTile() {
    var bunnyWidth = 47.0;
    var bunnyHeight = 75.0;
    var clipOvalWidth = 130.0;
    var holeOutlineStrokeWidth = 1.4;

    // depth into the hole
    var bunnyOffset =
        _bunnyExitAnim.value * bunnyHeight + _bunnyDuckAnimation.value * 4.0;

    return
        // Top level container with the hole and clipped bunny image
        Container(
      height: bunnyHeight + holeOutlineStrokeWidth,
      width: clipOvalWidth,
      child: Stack(
        children: <Widget>[
          // hole
          Opacity(
            opacity: 1.0 - _holeTransformAnim.value,
            child: Align(
                alignment: Alignment.bottomCenter,
                child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()
                      ..scale(1.0 - _holeTransformAnim.value,
                          1.0 + _holeTransformAnim.value),
                    child: Image.asset("assets/images/layer35.png"))),
          ),
          // logo
          Opacity(
            opacity: _holeTransformAnim.value,
            child: Align(
                alignment: Alignment.bottomCenter,
                child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()
                      ..scale(1.0, _holeTransformAnim.value),
                    child: Image.asset("assets/images/logo_purple.png"))),
          ),

          // positioned oval clipped bunny
          Positioned(
              // clipping oval should sit on the top of the hole outline
              bottom: holeOutlineStrokeWidth,
              child: _buildOvalClippedBunny(
                bunnyHeight: bunnyHeight,
                bunnyWidth: bunnyWidth,
                clipOvalWidth: clipOvalWidth,
                bunnyOffset: bunnyOffset,
              )),
        ],
      ),
    );
  }

  // The ending (bottom) tile with the island and clipped bunny image
  Widget _buildEndTile() {
    var bunnyWidth = 30.0;
    var bunnyHeight = 48.0;
    var clipOvalWidth = 83.0;

    // depth into the hole
    var bunnyOffset = (1.0 - _bunnyEnterAnim.value) * bunnyHeight;
    var containerWidth = 375.0;

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        // Set the overall size of the layout, leaving space for the background
        Container(width: containerWidth, height: 200),

        // connected animation
        _buildBackgroundAnimation(),

        // island
        Image.asset("assets/images/island.png"),
        Opacity(
            opacity: _connectAnimController.value,
            child: Image.asset("assets/images/vignetteHomeHeroSm.png")),

        // positioned bunny
        Positioned(
            // clipping oval should sit on the top of the hole outline
            top: 70.0,
            left: containerWidth / 2 - clipOvalWidth / 2 + 5,
            child: _buildOvalClippedBunny(
              bunnyHeight: bunnyHeight,
              bunnyWidth: bunnyWidth,
              clipOvalWidth: clipOvalWidth,
              bunnyOffset: bunnyOffset,
            )),
      ],
    );
  }

  // Note: I tried a number of things here to position this relative to screen
  // Note: width but nothing was very satisfying. This animation really should
  // Note: probably be aligned with the island but stacked under the whole layout
  // Note: with a transparent gradient extending under the other screen items.
  // Note: Going with a fixed layout for now.
  Widget _buildBackgroundAnimation() {
    return Positioned(
      top: -38,
      child: Container(
        width: 375,
        height: 350,
        child: Opacity(
          opacity: _connectAnimController.value,
          child: FlareActor(
            "assets/flare/Connection_screens.flr",
            color: Colors.deepPurple.withOpacity(0.4),
            fit: BoxFit.fitHeight,
            animation: "connectedLoop",
          ),
        ),
      ),
    );
  }

  // A transparent oval clipping container for the bunny with specified offset
  ClipOval _buildOvalClippedBunny(
      {double bunnyHeight,
      double bunnyWidth,
      double clipOvalWidth,
      double bunnyOffset}) {
    return ClipOval(
      child: Container(
          width: clipOvalWidth, // width of the hole
          height: bunnyHeight,
          //color: Colors.grey.withOpacity(0.3), // show clipping oval
          child: Stack(
            children: <Widget>[
              Positioned(
                  bottom: -bunnyOffset,
                  left: clipOvalWidth / 2 - bunnyWidth / 2 + 5,
                  child: Image.asset("assets/images/bunnypeek.png",
                      height: bunnyHeight)),
            ],
          )),
    );
  }

  Widget _buildNewHopTile() {
    return HopTile(
        title: s.newHop,
        image: Image.asset("assets/images/addCircleOutline.png"),
        trailing: SizedBox(width: 40),
        // match leading
        textColor: Colors.deepPurple,
        borderColor: Color(0xffb88dfc),
        dottedBorder: true,
        showDragHandle: false,
        onTap: _addHop);
  }

  Widget _buildStatusTile() {
    String text = s.orchidDisabled;
    Color color = Colors.redAccent.withOpacity(0.7);
    if (_connected()) {
      if (_hasHops()) {
        var num = _hops.length;
        text = s.numHopsConfigured(num);
        color = Colors.greenAccent.withOpacity(0.7);
      } else {
        text = s.trafficMonitoringOnly;
        color = Colors.yellowAccent.withOpacity(0.7);
      }
    }

    var status = OrchidAPI().connectionStatus.value;
    if (status == OrchidConnectionState.Connecting) {
      text = s.orchidConnecting;
      color = Colors.yellowAccent.withOpacity(0.7);
    }
    if (status == OrchidConnectionState.Disconnecting) {
      text = s.orchidDisconnecting;
      color = Colors.yellowAccent.withOpacity(0.7);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16.0, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.fiber_manual_record, color: color, size: 18),
          padx(5),
          Text(text,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: Color(0xff504960),
              )),
        ],
      ),
    );
  }

  Dismissible _buildDismissableHopTile(UniqueHop uniqueHop) {
    return Dismissible(
      key: Key(uniqueHop.key.toString()),
      background: Container(
        color: Colors.red,
        child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                s.delete,
                style: TextStyle(color: Colors.white),
              ),
            )),
      ),
      onDismissed: (direction) {
        _deleteHop(uniqueHop);
      },
      child: _buildHopTile(uniqueHop),
    );
  }

  Widget _buildHopTile(UniqueHop uniqueHop) {
    //bool isFirstHop = uniqueHop.key == _hops.first.key;
    //bool hasMultipleHops = _hops.length > 1;
    //bool isLastHop = uniqueHop.key == _hops.last.key;
    Color color = Colors.white;
    Image image;
    switch (uniqueHop.hop.protocol) {
      case HopProtocol.Orchid:
        image = Image.asset("assets/images/logo2.png", color: color);
        break;
      case HopProtocol.OpenVPN:
        image = Image.asset("assets/images/security.png", color: color);
        break;
      default:
        throw new Exception();
    }
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: HopTile(
        showAlertBadge: _showHopAlert[uniqueHop] ?? false,
        textColor: color,
        color: _hopColorTween.value,
        image: image,
        onTap: () {
          _viewHop(uniqueHop);
        },
        key: Key(uniqueHop.key.toString()),
        title: uniqueHop.hop.displayName(context),
        showTopDivider: false,
      ),
    );
  }

  Container _buildEnableVPNInstruction() {
    return Container(
        padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 16),
        child: SafeArea(
          bottom: false,
          left: false,
          top: false,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(s.turnOnToActivate,
                    textAlign: TextAlign.right,
                    style: AppText.hopsInstructionsCallout),
              ),
              Padding(
                // attempt to align the arrow with switch in the header and text vertically
                padding: const EdgeInsets.only(left: 16, right: 6, bottom: 16),
                child: Image.asset("assets/images/drawnArrow3.png", height: 48),
              ),
            ],
          ),
        ));
  }

  Container _buildFirstHopInstruction() {
    return Container(
        // match hop tile horizontal padding
        padding: EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 0),
        child: SafeArea(
          left: true,
          bottom: false,
          right: false,
          top: false,
          child: Row(
            children: <Widget>[
              Padding(
                // align the arrow with the hop tile leading and text vertically
                padding: const EdgeInsets.only(left: 19, right: 0, bottom: 24),
                child: Image.asset("assets/images/drawnArrow2.png", height: 48),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16),
                  child: Text(s.createFirstHop,
                      textAlign: TextAlign.left,
                      style: AppText.hopsInstructionsCallout),
                ),
              ),
            ],
          ),
        ));
  }

  ///
  /// Begin - Add / view hop logic
  ///

  // Show the add hop flow and save the result if completed successfully.
  void _addHop() async {
    // Create a nested navigation context for the flow. Performing a pop() from
    // this outer context at any point will properly remove the entire flow
    // (possibly multiple screens) with one appropriate animation.
    Navigator addFlow = Navigator(
      onGenerateRoute: (RouteSettings settings) {
        var addFlowCompletion = (CircuitHop result) {
          Navigator.pop(context, result);
        };
        var editor = AddHopPage(
            onAddFlowComplete: addFlowCompletion, showCallouts: _hops.isEmpty);
        var route = MaterialPageRoute<CircuitHop>(
            builder: (context) => editor, settings: settings);
        return route;
      },
    );
    var route = MaterialPageRoute<CircuitHop>(
        builder: (context) => addFlow, fullscreenDialog: true);
    _pushEditorRoute(route);
  }

  // Show the purchase PAC screen directly as a modal, skipping the "add hop"
  // choice screen. This is used by the welcome dialog.
  void _addHopFromPACPurchase() async {
    var addFlowCompletion = (CircuitHop result) {
      Navigator.pop(context, result);
    };
    var route = MaterialPageRoute<CircuitHop>(
        builder: (BuildContext context) {
          return PurchasePage(
            onAddFlowComplete: addFlowCompletion,
            cancellable: true,
          );
        },
        fullscreenDialog: true);
    _pushEditorRoute(route);
  }

  // Push the specified hop editor, await the hop result, and save it to the circuit.
  // Note: The paradigm here of the hop editors returning newly created or edited hops
  // Note: on the navigation stack decouples them but makes them more dependent on
  // Note: this update and save logic. We should consider centralizing this logic and
  // Note: relying on observation with `OrchidAPI.circuitConfigurationChanged` here.
  // Note: e.g.
  // Note: void _AddHopExternal(CircuitHop hop) async {
  // Note:   var circuit = await UserPreferences().getCircuit() ?? Circuit([]);
  // Note:   circuit.hops.add(hop);
  // Note:   await UserPreferences().setCircuit(circuit);
  // Note:   OrchidAPI().updateConfiguration();
  // Note:   OrchidAPI().circuitConfigurationChanged.add(null);
  // Note: }
  void _pushEditorRoute(MaterialPageRoute route) async {
    var hop = await Navigator.push(context, route);
    if (hop == null) {
      return; // user cancelled
    }
    var uniqueHop =
        UniqueHop(hop: hop, key: DateTime.now().millisecondsSinceEpoch);
    setState(() {
      _hops.add(uniqueHop);
    });
    _saveCircuit();

    // View the newly created hop:
    // Note: We would like this to behave like the iOS Contacts add flow,
    // Note: revealing the already pushed navigation state upon completing the
    // Note: add flow.  The non-animated push approximates this.
    _viewHop(uniqueHop, animated: false);
  }

  // View a hop selected from the circuit list
  void _viewHop(UniqueHop uniqueHop, {bool animated = true}) async {
    EditableHop editableHop = EditableHop(uniqueHop);
    var editor;
    switch (uniqueHop.hop.protocol) {
      case HopProtocol.Orchid:
        editor =
            OrchidHopPage(editableHop: editableHop, mode: HopEditorMode.View);
        break;
      case HopProtocol.OpenVPN:
        editor = OpenVPNHopPage(
          editableHop: editableHop,
          mode: HopEditorMode.Edit,
        );
        break;
    }
    await _showEditor(editor, animated: animated);

    // TODO: avoid saving if the hop was not edited.
    // Save the hop if it was edited.
    var index = _hops.indexOf(uniqueHop);
    setState(() {
      _hops.removeAt(index);
      _hops.insert(index, editableHop.value);
    });
    _saveCircuit();
  }

  Future<void> _showEditor(editor, {bool animated = true}) async {
    var route = animated
        ? MaterialPageRoute(builder: (context) => editor)
        : NoAnimationMaterialPageRoute(builder: (context) => editor);
    await Navigator.push(context, route);
  }

  // Callback for swipe to delete
  void _deleteHop(UniqueHop uniqueHop) {
    var index = _hops.indexOf(uniqueHop);
    setState(() {
      _hops.removeAt(index);
    });
    _saveCircuit();
  }

  // Callback for drag to reorder
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final UniqueHop hop = _hops.removeAt(oldIndex);
      _hops.insert(newIndex, hop);
    });
    _saveCircuit();
  }

  ///
  /// Begin - VPN Switch Logic
  ///

  // Note: By design the switch on this page does not track or respond to the
  // Note: connection state after initialization.  See `monitoring_page.dart`
  // Note: for a version of the switch that does attempt to track the connection.
  void _connectSwitchChanged(bool toEnabled) async {
    if (toEnabled) {
      bool allowNoHopVPN = await UserPreferences().getAllowNoHopVPN();
      if (_hasHops() || allowNoHopVPN) {
        _checkPermissionAndConnect();
      } else {
        _switchOn = false; // force the switch off
        _showWelcomeDialog();
      }
    } else {
      _disconnect();
    }
  }

  // Note: By design the switch on this page does not track or respond to the
  // Note: connection state after initialization.  See `monitoring_page.dart`
  // Note: for a version of the switch that does attempt to track the connection.
  bool _connected() {
    var state = OrchidAPI().connectionStatus.value;
    switch (state) {
      case OrchidConnectionState.Disconnecting:
      case OrchidConnectionState.Invalid:
      case OrchidConnectionState.NotConnected:
        return false;
      case OrchidConnectionState.Connecting:
      case OrchidConnectionState.Connected:
        return true;
      default:
        throw Exception();
    }
  }

  /// Called upon a change to Orchid connection state
  void _connectionStateChanged(OrchidConnectionState state,
      {bool animated = true}) {
    // We can't determine which animations may need to be run until hops are loaded.
    // Initialization will call us at least once after that.
    if (_hops == null) {
      return;
    }

    // Run animations based on which direction we are going.
    bool shouldShowConnected = _connected();
    bool showingConnected =
        _masterConnectAnimController.status == AnimationStatus.completed ||
            _masterConnectAnimController.status == AnimationStatus.forward;

    if (shouldShowConnected && !showingConnected && _hasHops()) {
      _masterConnectAnimController.forward(from: animated ? 0.0 : 1.0);
    }
    if (!shouldShowConnected && showingConnected) {
      _masterConnectAnimController.reverse(from: animated ? 1.0 : 0.0);
    }
    if (mounted) {
      setState(() {});
    }
  }

  // Prompt for VPN permissions if needed and then start the VPN.
  // Note: If the UI will no longer be participating in the prompt then
  // Note: we can just do this routinely in the channel api on first launch.
  // Note: duplicates code in monitoring_page and connect_page.
  void _checkPermissionAndConnect() {
    UserPreferences().setDesiredVPNState(true);
    if (_showEnableVPNInstruction()) {
      UserPreferences().setVPNSwitchInstructionsViewed(true);
      setState(() {
        vpnSwitchInstructionsViewed = true;
      });
    }
    // Get the most recent status, blocking if needed.
    _rxSubs
        .add(OrchidAPI().vpnPermissionStatus.take(1).listen((installed) async {
      if (installed) {
        OrchidAPI().setConnected(true);
        setState(() {
          _switchOn = true;
        });
      } else {
        bool ok = await OrchidAPI().requestVPNPermission();
        if (ok) {
          debugPrint("vpn: user chose to install");
          // Note: It appears that trying to enable the connection too quickly
          // Note: after installing the vpn permission / config fails.
          // Note: Introducing a short artificial delay.
          Future.delayed(Duration(milliseconds: 500)).then((_) {
            OrchidAPI().setConnected(true);
          });
          setState(() {
            _switchOn = true;
          });
        } else {
          debugPrint("vpn: user skipped");
          setState(() {
            _switchOn = false;
          });
        }
      }
    }));
  }

  // Disconnect the VPN
  void _disconnect() {
    UserPreferences().setDesiredVPNState(false);
    OrchidAPI().setConnected(false);
    setState(() {
      _switchOn = false;
    });
  }

  ///
  /// Begin - util
  ///

  // Setter for the switch controller controlled state
  set _switchOn(bool on) {
    if (widget.switchController == null) {
      return;
    }
    widget.switchController.controlledState.value = on;
  }

  // Getter for the switch controller controlled state
  bool get _switchOn {
    return widget.switchController?.controlledState?.value ?? false;
  }

  bool _hasHops() {
    return _hops != null && _hops.length > 0;
  }

  void _saveCircuit() async {
    var circuit = Circuit(_hops.map((uniqueHop) => uniqueHop.hop).toList());
    UserPreferences().setCircuit(circuit);
    OrchidAPI().updateConfiguration();
    if (_dialogInProgress) {
      return;
    }
    try {
      _dialogInProgress = true;
      await Dialogs.showConfigurationChangeSuccess(context, warnOnly: true);
    } finally {
      _dialogInProgress = false;
    }
  }

  void _showWelcomeDialog() async {
    var pacsEnabled = (await OrchidPurchaseAPI().apiConfig()).enabled;
    if (pacsEnabled) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return WelcomeDialog(
              onBuyCredits: _addHopFromPACPurchase,
              onSeeOptions: _addHop,
            );
          });
    } else {
      // TODO: Remove after PACs are in place on all platforms or when an alternate
      // TODO: fallback for the PACs feature flag exists.
      LegacyWelcomeDialog.show(
          context: context, onAddFlowComplete: _legacyWelcomeScreenAddHop);
    }
  }

  // TODO: Remove after PACs are in place on all platforms or when an alternate
  // TODO: fallback for the PACs feature flag exists.
  void _legacyWelcomeScreenAddHop(CircuitHop hop) async {
    var circuit = await UserPreferences().getCircuit() ?? Circuit([]);
    circuit.hops.add(hop);
    await UserPreferences().setCircuit(circuit);
    OrchidAPI().updateConfiguration();
    // Notify that the hops config has changed externally
    OrchidAPI().circuitConfigurationChanged.add(null);
  }

  void _userInteraction() {
    if (_bunnyDuckAnimation.value == 0) {
      _bunnyDuckAnimController.forward();
    }
    _lastInteractionTime = DateTime.now();
  }

  void _checkBunny(Timer timer) {
    var bunnyHideTime = Duration(seconds: 3);
    if (_bunnyDuckAnimation.value == 1.0 &&
        DateTime.now().difference(_lastInteractionTime) > bunnyHideTime) {
      _bunnyDuckAnimController.reverse();
    }
  }

  S get s {
    return S.of(context);
  }

  @override
  void dispose() {
    _rxSubs.forEach((sub) {
      sub.cancel();
    });
    _bunnyDuckTimer.cancel();
    widget.switchController.onChange = null;
    _checkBalancesTimer.cancel();
    super.dispose();
  }
}
