class FactionMetadata {
  final String id;
  final String slug;
  final String name;
  final String remoteFile;
  final int expectedUnits;

  const FactionMetadata({
    required this.id,
    required this.slug,
    required this.name,
    required this.remoteFile,
    required this.expectedUnits,
  });
}

class FactionRegistry {
  static const List<FactionMetadata> allFactions = [
    FactionMetadata(
      id: 'b39e-4401-8f3e-fdf7',
      slug: 'adepta-sororitas',
      name: 'Adepta Sororitas',
      remoteFile: 'Adepta_Sororitas.json',
      expectedUnits: 34,
    ),
    FactionMetadata(
      id: '36d3-36bc-68dd-40ac',
      slug: 'black-templars',
      name: 'Adeptus Astartes - Black Templars',
      remoteFile: 'Adeptus_Astartes_Black_Templars.json',
      expectedUnits: 16,
    ),
    FactionMetadata(
      id: '4ef9-15ce-e3e6-36de',
      slug: 'blood-angels',
      name: 'Adeptus Astartes - Blood Angels',
      remoteFile: 'Adeptus_Astartes_Blood_Angels.json',
      expectedUnits: 27,
    ),
    FactionMetadata(
      id: '470a-6daa-9014-12df',
      slug: 'dark-angels',
      name: 'Adeptus Astartes - Dark Angels',
      remoteFile: 'Adeptus_Astartes_Dark_Angels.json',
      expectedUnits: 17,
    ),
    FactionMetadata(
      id: '5d6e-fd3-330a-11dd',
      slug: 'imperial-fists',
      name: 'Adeptus Astartes - Imperial Fists',
      remoteFile: 'Adeptus_Astartes_Imperial_Fists.json',
      expectedUnits: 3,
    ),
    FactionMetadata(
      id: 'f27e-18c0-b73e-748e',
      slug: 'iron-hands',
      name: 'Adeptus Astartes - Iron Hands',
      remoteFile: 'Adeptus_Astartes_Iron_Hands.json',
      expectedUnits: 2,
    ),
    FactionMetadata(
      id: '6e59-e1ee-47ad-6ce5',
      slug: 'raven-guard',
      name: 'Adeptus Astartes - Raven Guard',
      remoteFile: 'Adeptus_Astartes_Raven_Guard.json',
      expectedUnits: 2,
    ),
    FactionMetadata(
      id: '2261-79a5-19d9-1668',
      slug: 'salamanders',
      name: 'Adeptus Astartes - Salamanders',
      remoteFile: 'Adeptus_Astartes_Salamanders.json',
      expectedUnits: 2,
    ),
    FactionMetadata(
      id: 'e0af-67df-9d63-8fb7',
      slug: 'space-marines',
      name: 'Adeptus Astartes - Space Marines',
      remoteFile: 'Adeptus_Astartes_Space_Marines.json',
      expectedUnits: 168,
    ),
    FactionMetadata(
      id: '94bb-3284-ee14-57a1',
      slug: 'space-wolves',
      name: 'Adeptus Astartes - Space Wolves',
      remoteFile: 'Adeptus_Astartes_Space_Wolves.json',
      expectedUnits: 39,
    ),
    FactionMetadata(
      id: '4029-9237-e8db-af55',
      slug: 'ultramarines',
      name: 'Adeptus Astartes - Ultramarines',
      remoteFile: 'Adeptus_Astartes_Ultramarines.json',
      expectedUnits: 16,
    ),
    FactionMetadata(
      id: '67c1-fc13-f9a1-cbbf',
      slug: 'white-scars',
      name: 'Adeptus Astartes - White Scars',
      remoteFile: 'Adeptus_Astartes_White_Scars.json',
      expectedUnits: 2,
    ),
    FactionMetadata(
      id: '1f19-6509-d906-ca10',
      slug: 'adeptus-custodes',
      name: 'Adeptus Custodes',
      remoteFile: 'Adeptus_Custodes.json',
      expectedUnits: 37,
    ),
    FactionMetadata(
      id: '77b9-2f66-3f9b-5cf3',
      slug: 'adeptus-mechanicus',
      name: 'Adeptus Mechanicus',
      remoteFile: 'Adeptus_Mechanicus.json',
      expectedUnits: 40,
    ),
    FactionMetadata(
      id: 'bdc0-c0d-72d7-87e2',
      slug: 'adeptus-titanicus',
      name: 'Adeptus Titanicus',
      remoteFile: 'Adeptus_Titanicus.json',
      expectedUnits: 4,
    ),
    FactionMetadata(
      id: 'b0ae-12a5-c84-ea45',
      slug: 'astra-militarum',
      name: 'Astra Militarum',
      remoteFile: 'Astra_Militarum.json',
      expectedUnits: 112,
    ),
    FactionMetadata(
      id: 'd265-877b-e03d-30ca',
      slug: 'chaos-daemons',
      name: 'Chaos Daemons',
      remoteFile: 'Chaos_Daemons.json',
      expectedUnits: 31,
    ),
    FactionMetadata(
      id: '46d8-abc8-ef3a-9f85',
      slug: 'chaos-knights',
      name: 'Chaos Knights',
      remoteFile: 'Chaos_Knights.json',
      expectedUnits: 17,
    ),
    FactionMetadata(
      id: 'c8da-e875-58f7-f6d6',
      slug: 'chaos-space-marines',
      name: 'Chaos Space Marines',
      remoteFile: 'Chaos_Space_Marines.json',
      expectedUnits: 114,
    ),
    FactionMetadata(
      id: '5108-f98-63c2-53cb',
      slug: 'death-guard',
      name: 'Death Guard',
      remoteFile: 'Death_Guard.json',
      expectedUnits: 77,
    ),
    FactionMetadata(
      id: '03fe-a162-4c02-f07b',
      slug: 'emperors-children',
      name: "Emperor's Children",
      remoteFile: 'Emperors_Children.json',
      expectedUnits: 29,
    ),
    FactionMetadata(
      id: '50c4-3e83-fe54-97c4',
      slug: 'grey-knights',
      name: 'Grey Knights',
      remoteFile: 'Grey_Knights.json',
      expectedUnits: 31,
    ),
    FactionMetadata(
      id: 'b00-cd86-4b4c-97ba',
      slug: 'imperial-agents',
      name: 'Imperial Agents',
      remoteFile: 'Imperial_Agents.json',
      expectedUnits: 47,
    ),
    FactionMetadata(
      id: '25dd-7aa0-6bf4-f2d5',
      slug: 'imperial-knights',
      name: 'Imperial Knights',
      remoteFile: 'Imperial_Knights.json',
      expectedUnits: 5,
    ),
    FactionMetadata(
      id: '1069-10ff-3ba9-873b',
      slug: 'thousand-sons',
      name: 'Thousand Sons',
      remoteFile: 'Thousand_Sons.json',
      expectedUnits: 67,
    ),
    FactionMetadata(
      id: '880c-c7e-4a43-a0c1',
      slug: 'titanicus-traitoris',
      name: 'Titanicus Traitoris',
      remoteFile: 'Titanicus_Traitoris.json',
      expectedUnits: 4,
    ),
    FactionMetadata(
      id: 'df9a-59b2-f464-59ad',
      slug: 'world-eaters',
      name: 'World Eaters',
      remoteFile: 'World_Eaters.json',
      expectedUnits: 63,
    ),
    FactionMetadata(
      id: '34a5-8c7e-f468-82d1',
      slug: 'aeldari',
      name: 'Xenos - Aeldari',
      remoteFile: 'Aeldari.json',
      expectedUnits: 88,
    ),
    FactionMetadata(
      id: '38de-521f-1ce0-44a0',
      slug: 'drukhari',
      name: 'Xenos - Drukhari',
      remoteFile: 'Drukhari.json',
      expectedUnits: 31,
    ),
    FactionMetadata(
      id: '3bdf-a114-5035-c6ac',
      slug: 'genestealer-cults',
      name: 'Xenos - Genestealer Cults',
      remoteFile: 'Genestealer_Cults.json',
      expectedUnits: 130,
    ),
    FactionMetadata(
      id: 'f616-3f08-ee8e-3349',
      slug: 'leagues-of-votann',
      name: 'Xenos - Leagues of Votann',
      remoteFile: 'Leagues_of_Votann.json',
      expectedUnits: 25,
    ),
    FactionMetadata(
      id: 'b654-a18a-ea1-3bf2',
      slug: 'necrons',
      name: 'Xenos - Necrons',
      remoteFile: 'Necrons.json',
      expectedUnits: 67,
    ),
    FactionMetadata(
      id: 'a55f-b7b3-6c65-a05f',
      slug: 'orks',
      name: 'Xenos - Orks',
      remoteFile: 'Orks.json',
      expectedUnits: 65,
    ),
    FactionMetadata(
      id: 'd81a-61dd-6d27-a3ce',
      slug: 'tau-empire',
      name: "Xenos - T'au Empire",
      remoteFile: 'Tau_Empire.json',
      expectedUnits: 64,
    ),
    FactionMetadata(
      id: 'b984-7317-81cc-20f',
      slug: 'tyranids',
      name: 'Xenos - Tyranids',
      remoteFile: 'Tyranids.json',
      expectedUnits: 55,
    ),
  ];

  static FactionMetadata? find(String idOrSlugOrName) {
    final clean = idOrSlugOrName.trim().toLowerCase();
    for (final f in allFactions) {
      if (f.id.toLowerCase() == clean ||
          f.slug.toLowerCase() == clean ||
          f.name.toLowerCase() == clean) {
        return f;
      }
    }
    // Partial substring match
    for (final f in allFactions) {
      if (f.name.toLowerCase().contains(clean) ||
          f.slug.toLowerCase().contains(clean)) {
        return f;
      }
    }
    return null;
  }
}
