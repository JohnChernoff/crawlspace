import 'dart:math';

import 'package:crawlspace_engine/stock_items/species.dart';

const Map<String,StockSpecies> speciesThrows = {
  "Planet" : StockSpecies.humanoid,
  "Nebula" : StockSpecies.vorlon,
  "Quasar" : StockSpecies.gersh,
  "Star" : StockSpecies.lael,
  "Black Hole" : StockSpecies.orblix,
  "Asteroid" : StockSpecies.moveliean,
  "Supernova" : StockSpecies.krakkar,
  "Singularity" : StockSpecies.edualx
};

const List<String> zodThrows = [
  "Aquarius",  "Pieces",  "Aries",  "Taurus",  "Gemini",  "Cancer",  "Leo",
  "Virgo",  "Libra", "Scorpio",  "Sagittarius",  "Capricorn"
];

const List<String> starThrows = [
  "Sirius", "Canopus", "Alpha Centauri", "Betelgeuse", "Rigel", "Vega",
  "Capella", "Arcturus", "Altair", "Aldebaran", "Antares",  "Polaris",
  //"Deneb", "Proxima Centauri", "Tau Ceti"
];

const List<String> authorThrows = [
  "Asimov", "Clarke", "Heinlein", "LeGuin", "Dick", "Bradbury",
  "Niven", "Pohl", "Ellison", "Silverberg", "Sturgeon", "Harrison",
  //"Sheckley", "Simak", "Brin"
];

const List<String> celestialThrows = [
  "Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn",
  "Uranus", "Neptune", "Titan", "Europa", "Io ", "Triton",
  //"Ganymede", "Miranda", "Enceladus"
];

const List<String> quantumThrows = [
  "Planck", "Heisenberg", "Schrödinger", "Born", "Pauli", "Feynman",
  "Bohr", "Einstein", "Dirac", "von Neumann", "Hawking", "Fermi"
  // "Bell", "Everett", "Aspect", "Zeilinger","Susskind", "Wheeler", "Wigner",
];

enum ThrowList {
  zodiac(zodThrows),
  stars(starThrows),
  authors(authorThrows),
  celestial(celestialThrows),
  quantum(quantumThrows);

  final List<String> list;
  const ThrowList(this.list);

  String rndThrow(Random rnd) => list.elementAt(rnd.nextInt(list.length));

  static ThrowList rndList(Random rnd) => ThrowList.values.elementAt(rnd.nextInt(ThrowList.values.length));
}
