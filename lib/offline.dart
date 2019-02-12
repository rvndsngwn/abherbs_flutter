import 'dart:async';
import 'dart:io';

import 'package:abherbs_flutter/entity/plant.dart';
import 'package:abherbs_flutter/prefs.dart';
import 'package:abherbs_flutter/purchases.dart';
import 'package:abherbs_flutter/utils.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class Offline {
  static var httpClient = new HttpClient();
  static String rootPath;
  static bool downloadFinished = false;
  static bool downloadPaused = false;
  static bool downloadDB = false;
  static String downloadDBDate;
  static List<bool> keepSynced = [false, false, false, false];

  static void initialize() {
    getApplicationDocumentsDirectory().then((dir) {
      rootPath = dir.path;
    });

    if (Purchases.isOffline()) {
      FirebaseDatabase.instance.setPersistenceEnabled(true);
      FirebaseDatabase.instance.setPersistenceCacheSizeBytes(firebaseCacheSize);

      Prefs.getBoolF(keyOffline, false).then((value) {
        if (value) {
          Prefs.getIntF(keyOfflinePlant, 0).then((value) {
            FirebaseDatabase.instance.reference().child(firebasePlantsToUpdate).child(firebaseAttributeCount).once().then((DataSnapshot snapshot) {
              downloadFinished = snapshot.value == null || value >= snapshot.value;
            });
          });
        } else {
          downloadFinished = false;
        }
      });

      FirebaseDatabase.instance.reference().child(firebaseVersions).child(firebaseAttributeLastUpdate).once().then((DataSnapshot snapshot) {
        if (snapshot.value != null) {
          Prefs.getStringF(keyOfflineDB, '').then((value) {
            downloadDBDate = snapshot.value;
            DateTime dbUpdate = DateTime.parse(downloadDBDate);
            downloadDB = value.isEmpty || dbUpdate.isAfter(DateTime.parse(value));
          });
        }
      });
    }
  }

  static void finalizeDownloadDB() {
    if (Purchases.isOffline() && keepSynced.reduce((value, item) => value && item)) {
      Prefs.setString(keyOfflineDB, downloadDBDate);
      downloadDB = false;
    }
  }

  static void setKeepSynced1(bool value) {
    if (Purchases.isOffline() && downloadDB && !keepSynced[0]) {
      var reference = FirebaseDatabase.instance.reference();
      reference.child(firebaseCounts).keepSynced(value);
      keepSynced[0] = true;
      finalizeDownloadDB();
    }
  }

  static void setKeepSynced2(bool value) {
    if (Purchases.isOffline() && downloadDB && !keepSynced[1]) {
      var reference = FirebaseDatabase.instance.reference();
      reference.child(firebaseLists).keepSynced(value);
      reference.child(firebasePlantHeaders).keepSynced(value);
      keepSynced[1] = true;
      finalizeDownloadDB();
    }
  }

  static void setKeepSynced3(bool value) {
    if (Purchases.isOffline() && downloadDB && !keepSynced[2]) {
      var reference = FirebaseDatabase.instance.reference();
      reference.child(firebasePlants).keepSynced(value);
      reference.child(firebaseTranslations).child(languageEnglish).keepSynced(value);
      Prefs.getStringF(keyLanguage, languageEnglish).then((language) {
        reference.child(firebaseTranslations).child(language).keepSynced(value);
        reference.child(firebaseTranslations).child(language + languageGTSuffix).keepSynced(value);
        reference.child(firebaseTranslationsTaxonomy).child(language).keepSynced(value);
      });
      keepSynced[2] = true;
      finalizeDownloadDB();
    }
  }

  static void setKeepSynced4(bool value) {
    if (Purchases.isOffline() && downloadDB && !keepSynced[3]) {
      var reference = FirebaseDatabase.instance.reference();
      if (Purchases.isSearch()) {
        reference.child(firebaseAPGIV).keepSynced(value);
        reference.child(firebaseSearch).child(languageLatin).keepSynced(value);
        reference.child(firebaseSearch).child(languageEnglish).keepSynced(value);
        Prefs.getStringF(keyLanguage, languageEnglish).then((language) {
          if (language != languageEnglish) {
            reference.child(firebaseSearch).child(language).keepSynced(value);
          }
        });
      }
      keepSynced[3] = true;
      finalizeDownloadDB();
    }
  }

  static void download(
      Function(int, int) onFamilyDownload, Function(int, int) onPlantDownload, Function() onDownloadFinish, Function() onDownloadFail) {
    Future.wait([downloadFamilies(onFamilyDownload), _downloadPlants(onPlantDownload)]).then((List<bool> results) {
      downloadFinished = results.reduce((x, y) => x && y);
      if (downloadPaused) {
        downloadPaused = false;
        downloadFinished = false;
      } else if (downloadFinished) {
        onDownloadFinish();
      } else {
        onDownloadFail();
      }
    }).catchError((error) {
      onDownloadFail();
    });
  }

  static Future<bool> downloadFamilies(Function(int, int) onFamilyDownload) async {
    int position = await Prefs.getIntF(keyOfflineFamily, 0);
    int familyTotal = await FirebaseDatabase.instance
        .reference()
        .child(firebaseFamiliesToUpdate)
        .child(firebaseAttributeCount)
        .once()
        .then((DataSnapshot snapshot) {
      return snapshot.value ?? 0;
    });
    while (position < familyTotal) {
      if (await _downloadFamilyIcon(position)) {
        position++;
        Prefs.setInt(keyOfflineFamily, position);
        onFamilyDownload(position, familyTotal);
        if (downloadPaused) {
          break;
        }
      } else {
        return false;
      }
    }
    onFamilyDownload(position, familyTotal);
    return true;
  }

  static Future<bool> _downloadFamilyIcon(int position) async {
    String family = await FirebaseDatabase.instance
        .reference()
        .child(firebaseFamiliesToUpdate)
        .child(firebaseAttributeList)
        .child(position.toString())
        .once()
        .then((DataSnapshot snapshot) {
      return snapshot.value;
    });
    if (family != null) {
      var errors = 0;
      await _downloadFile(storageEndpoit + storageFamilies + family + defaultExtension, storageFamilies, family + defaultExtension)
          .catchError((error) {
        errors++;
      });
      return errors == 0;
    } else {
      return false;
    }
  }

  static Future<bool> _downloadPlants(Function(int, int) onPlantDownload) async {
    int position = await Prefs.getIntF(keyOfflinePlant, 0);
    int plantTotal =
        await FirebaseDatabase.instance.reference().child(firebasePlantsToUpdate).child(firebaseAttributeCount).once().then((DataSnapshot snapshot) {
      return snapshot.value ?? 0;
    });
    while (position < plantTotal) {
      if (await _downloadPlantPhotos(position)) {
        position++;
        Prefs.setInt(keyOfflinePlant, position);
        onPlantDownload(position, plantTotal);
        if (downloadPaused) {
          break;
        }
      } else {
        return false;
      }
    }

    onPlantDownload(position, plantTotal);
    return true;
  }

  static Future<bool> _downloadPlantPhotos(int position) async {
    String url;
    String plantName =
        await FirebaseDatabase.instance.reference().child(firebasePlantHeaders).child(position.toString()).once().then((DataSnapshot snapshot) {
      url = snapshot.value == null ? null : snapshot.value['url'];
      return snapshot.value == null ? null : snapshot.value['name'];
    });
    if (plantName != null) {
      Plant plant = await FirebaseDatabase.instance.reference().child(firebasePlants).child(plantName).once().then((DataSnapshot snapshot) {
        return Plant.fromJson(snapshot.key, snapshot.value);
      });
      if (plant != null) {
        var errors = 0;
        var urls = <String>[];
        urls.addAll(plant.photoUrls.map((url) => url as String));
        urls.add(plant.illustrationUrl);
        if (url != plant.photoUrls[0]) {
          urls.add(url);
        }
        await Future.wait(urls.map((String url) {
          return _downloadFile(storageEndpoit + storagePhotos + url, storagePhotos + url.substring(0, url.lastIndexOf('/')),
                  url.substring(url.lastIndexOf('/') + 1))
              .catchError((error) {
            errors++;
          });
        }));

        return errors == 0;
      } else {
        return false;
      }
    } else {
      return false;
    }
  }

  static Future<void> delete() async {
    setKeepSynced1(false);
    setKeepSynced2(false);
    setKeepSynced3(false);
    setKeepSynced4(false);
    if (rootPath == null) {
      rootPath = (await getApplicationDocumentsDirectory()).path;
    }
    var familiesDir = Directory('$rootPath/$storageFamilies');
    familiesDir.delete(recursive: true);
    var photosDir = Directory('$rootPath/$storagePhotos');
    photosDir.delete(recursive: true);
    Prefs.setInt(keyOfflineFamily, 0);
    Prefs.setInt(keyOfflinePlant, 0);
    downloadFinished = false;
  }

  static Future<File> _downloadFile(String url, String dir, String filename) async {
    var request = await httpClient.getUrl(Uri.parse(url));
    var response = await request.close();
    var bytes = await consolidateHttpClientResponseBytes(response);
    if (rootPath == null) {
      rootPath = (await getApplicationDocumentsDirectory()).path;
    }
    await Directory('$rootPath/$dir').create(recursive: true);
    File file = File('$rootPath/$dir/$filename');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<File> getLocalFile(String filename) async {
    if (rootPath == null) {
      rootPath = (await getApplicationDocumentsDirectory()).path;
    }
    File file = new File('$rootPath/$filename');
    return file.exists().then((exists) {
      return exists ? file : null;
    });
  }
}