/// Google Maps SDK JSON styles — minimal \"Uber-like\" light and dark palettes.
/// Applied only for [MapType.normal] / [MapType.terrain]; cleared for satellite/hybrid.
class HomeMapStyles {
  HomeMapStyles._();

  /// Clean light canvas, muted roads / water, fewer POIs.
  static const String lightUberLike = '['
      '{"elementType":"geometry","stylers":[{"color":"#f6f7f9"}]},'
      '{"elementType":"labels.icon","stylers":[{"visibility":"off"}]},'
      '{"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},'
      '{"featureType":"poi.business","stylers":[{"visibility":"off"}]},'
      '{"featureType":"poi.park","elementType":"labels","stylers":[{"visibility":"off"}]},'
      '{"featureType":"road","elementType":"geometry","stylers":[{"color":"#e8eaef"}]},'
      '{"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#dfe2eb"}]},'
      '{"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#676b7a"}]},'
      '{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#d8dce6"}]},'
      '{"featureType":"water","elementType":"geometry","stylers":[{"color":"#d4e9f7"}]},'
      '{"featureType":"transit","stylers":[{"visibility":"simplified"}]}'
      ']';

  /// Dark navigation-style canvas (Uber night-like).
  static const String darkUberLike = '['
      '{"elementType":"geometry","stylers":[{"color":"#242f3e"}]},'
      '{"elementType":"labels.icon","stylers":[{"visibility":"off"}]},'
      '{"elementType":"labels.text.fill","stylers":[{"color":"#dfe4ec"}]},'
      '{"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},'
      '{"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},'
      '{"featureType":"poi.business","stylers":[{"visibility":"off"}]},'
      '{"featureType":"road","elementType":"geometry","stylers":[{"color":"#2d3c52"}]},'
      '{"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#384c66"}]},'
      '{"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#b7c6dd"}]},'
      '{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3d5a87"}]},'
      '{"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#2c4260"}]},'
      '{"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},'
      '{"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},'
      '{"featureType":"transit","stylers":[{"visibility":"simplified"}]}'
      ']';
}
