import 'dart:async';
import 'dart:ui';

import 'package:dash_run/game/dash_run_game.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:ordered_set/comparing.dart';
import 'package:ordered_set/ordered_set.dart';

typedef ObjectGroupProximitySpawner = PositionComponent Function({
  required TiledObject tiledObject,
  required Sprite sprite,
});

class ObjectGroupProximityBuilder<Reference extends PositionComponent>
    extends Component with HasGameRef<DashRunGame> {
  ObjectGroupProximityBuilder({
    required this.proximity,
    required this.tilesetPath,
    required this.tileLayerName,
    required this.tileset,
    required this.componentBuilder,
  }) : firstGid = tileset.firstGid ?? 0;

  final int firstGid;
  final double proximity;
  final String tilesetPath;
  final String tileLayerName;
  final Tileset tileset;
  final ObjectGroupProximitySpawner componentBuilder;

  late SpriteSheet spritesheet;
  late final Image tiles;

  final _objects = OrderedSet<TiledObject>(
    Comparing.on((object) => object.x),
  );

  final Map<int, PositionComponent> _spawnedComponents = {};

  var _referenceIndex = 0;
  var _lastReferenceX = 0.0;
  var _referenceDirection = 1;

  late PositionComponent? currentReference;

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();

    currentReference = game.world.firstChild<Reference>();

    final layer = gameRef.leapMap.getTileLayer<ObjectGroup>(tileLayerName);
    tiles = await gameRef.images.load(tilesetPath);

    spritesheet = SpriteSheet(
      image: tiles,
      srcSize: Vector2.all(gameRef.tileSize),
    );

    _objects.addAll(layer.objects);

    _lastReferenceX = currentReference?.x ?? 0.0;
    _findPlayerIndex();
  }

  void _findPlayerIndex() {
    var i = _referenceIndex + _referenceDirection;

    if (i != _referenceIndex) {
      while (i >= 0 && i < _objects.length) {
        final object = _objects.elementAt(i);
        if (object.x > currentReference!.x) {
          _referenceIndex = i - _referenceDirection;
          break;
        }
        i += _referenceDirection;
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    final reference = this.currentReference;
    if (reference == null || !reference.isMounted) return;

    _referenceDirection = reference.x > _lastReferenceX
        ? 1
        : reference.x < _lastReferenceX
            ? -1
            : 0;

    _lastReferenceX = reference.x;

    if (_referenceDirection != 0) {
      _findPlayerIndex();

      for (final entry in _spawnedComponents.entries) {
        final component = entry.value;
        if ((component.x - reference.x).abs() > proximity) {
          component
            ..removeFromParent()
            ..removed.then((_) => _spawnedComponents.remove(entry.key));
        }
      }

      for (var i = _referenceIndex;
          i >= 0 && i < _objects.length;
          i += _referenceDirection) {
        final object = _objects.elementAt(i);
        if ((object.x - reference.x).abs() > proximity) {
          break;
        }

        if (_spawnedComponents.containsKey(object.id)) {
          continue;
        }

        final component = componentBuilder(
          tiledObject: object,
          sprite: spritesheet.getSpriteById(
            (object.gid ?? 0) - firstGid,
          ),
        );

        _spawnedComponents[object.id] = component;
        gameRef.leapMap.add(component);
      }
    }
  }
}