// ============================================================
// FITZONE EVOLUTION — Google Apps Script: Upload to Google Drive
// ============================================================
// Déployer en tant que Web App:
// 1. Créer un projet sur https://script.google.com
// 2. Coller ce code
// 3. Modifier FOLDER_ID ci-dessous avec l'ID de ton dossier Google Drive
// 4. Déployer > Nouvelle déploiement > Application Web
//    - Exécuter en tant que : Moi
//    - Qui peut accéder : Tout le monde
// 5. Copier l'URL du déploiement
// ============================================================

// ⚠️ REMPLACE PAR L'ID DE TON DOSSIER GOOGLE DRIVE
const FOLDER_ID = 'REMPLACER_PAR_TON_FOLDER_ID';

function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);
    const folder = DriveApp.getFolderById(FOLDER_ID);

    // Support single file or batch upload
    const files = data.files || [{ base64: data.base64, fileName: data.fileName, mimeType: data.mimeType }];
    const results = [];

    for (const file of files) {
      // Extraire le base64 pur (enlever le prefix data:image/jpeg;base64,)
      let raw = file.base64;
      if (raw.indexOf(',') > -1) raw = raw.split(',')[1];

      const blob = Utilities.newBlob(
        Utilities.base64Decode(raw),
        file.mimeType || 'image/jpeg',
        file.fileName || ('fitzone_' + new Date().getTime() + '.jpg')
      );

      const driveFile = folder.createFile(blob);
      driveFile.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);

      // URL adaptée: images -> uc?export=view (affichage inline), autres (vidéos) -> /file/d/ID/view
      const mime = file.mimeType || '';
      const isImage = mime.indexOf('image/') === 0;
      const viewUrl = isImage
        ? 'https://drive.google.com/uc?export=view&id=' + driveFile.getId()
        : 'https://drive.google.com/file/d/' + driveFile.getId() + '/view';

      results.push({
        id: driveFile.getId(),
        url: viewUrl,
        name: driveFile.getName()
      });
    }

    return ContentService
      .createTextOutput(JSON.stringify({ success: true, files: results }))
      .setMimeType(ContentService.MimeType.JSON);

  } catch (err) {
    return ContentService
      .createTextOutput(JSON.stringify({ success: false, error: err.message }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

// Test function (run manually to verify access)
function testAccess() {
  const folder = DriveApp.getFolderById(FOLDER_ID);
  Logger.log('Folder name: ' + folder.getName());
  Logger.log('Access OK!');
}
