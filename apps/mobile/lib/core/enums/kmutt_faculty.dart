enum KmuttFaculty {
  engineering('Faculty of Engineering'),
  science('Faculty of Science'),
  liberalArts('School of Liberal Arts'),
  informationTechnology('School of Information Technology'),
  industrialEducation('Faculty of Industrial Education and Technology'),
  bioresources('School of Bioresources and Technology'),
  architecture('School of Architecture and Design'),
  energyEnvironment('School of Energy, Environment and Materials'),
  fieldRobotics('Institute of Field Robotics'),
  other('Other');

  const KmuttFaculty(this.label);

  final String label;
}
