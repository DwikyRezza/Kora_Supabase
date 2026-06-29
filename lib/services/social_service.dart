import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_service.dart';
import 'notification_service.dart';
class SocialService {
  static final _firestore = FirebaseFirestore.instance;

  static Future<void> _triggerVercelFCM(String targetUid, String title, String body) async {
    try {
      final vercelUrl = dotenv.env['VERCEL_URL'];
      if (vercelUrl == null || vercelUrl.isEmpty) return; // Skip if no Vercel backend yet
      
      final doc = await _firestore.collection('users').doc(targetUid).get();
      if (!doc.exists) return;
      final fcmToken = doc.data()?['fcmToken'] as String?;
      if (fcmToken == null || fcmToken.isEmpty) return;

      await http.post(
        Uri.parse('$vercelUrl/api/notify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fcmToken': fcmToken,
          'title': title,
          'body': body,
        }),
      );
    } catch (e) {
      print('[SocialService] Error triggering Vercel FCM: $e');
    }
  }

  /// Mendapatkan jumlah pengikut (followers) dari seorang pengguna
  static Future<int> getFollowersCount(String uid) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('followers')
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      print('[SocialService] Error getFollowersCount: $e');
      return 0;
    }
  }

  /// Mendapatkan jumlah pengguna yang diikuti (following)
  static Future<int> getFollowingCount(String uid) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('following')
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      print('[SocialService] Error getFollowingCount: $e');
      return 0;
    }
  }

  /// Mem-follow pengguna lain (Persiapan untuk fitur mendatang)
  static Future<void> followUser(String targetUid) async {
    if (!AuthService.isLoggedIn) return;
    final currentUid = AuthService.uid;
    if (currentUid == targetUid) return;

    try {
      final batch = _firestore.batch();
      
      // Tambahkan targetUid ke following milik currentUid
      final followingRef = _firestore.collection('users').doc(currentUid).collection('following').doc(targetUid);
      batch.set(followingRef, {'timestamp': FieldValue.serverTimestamp()});

      // Tambahkan currentUid ke followers milik targetUid
      final followerRef = _firestore.collection('users').doc(targetUid).collection('followers').doc(currentUid);
      batch.set(followerRef, {'timestamp': FieldValue.serverTimestamp()});

      await batch.commit();
      print('[SocialService] Berhasil follow user $targetUid');

      // Kirim Notifikasi ke targetUid
      final currentUserDoc = await _firestore.collection('users').doc(currentUid).get();
      if (currentUserDoc.exists) {
        final data = currentUserDoc.data()!;
        final profile = data.containsKey('profile')
            ? Map<String, dynamic>.from(data['profile'] as Map)
            : data;
        final username = profile['username'] as String?;
        final name = profile['name'] as String?;
        final display = (username != null && username.isNotEmpty)
            ? '@$username'
            : (name ?? 'Seseorang');
        final photoUrl = profile['photoUrl'];

        await NotificationService.addNotification(
          targetUid,
          title: 'Pengikut Baru',
          body: '$display mulai mengikuti Anda.',
          type: 'follow',
          relatedUid: currentUid,
          relatedPhotoUrl: photoUrl,
        );
        
        await _triggerVercelFCM(targetUid, 'Pengikut Baru', '$display mulai mengikuti Anda.');
      }

    } catch (e) {
      print('[SocialService] Error followUser: $e');
    }
  }

  /// Unfollow pengguna lain
  static Future<void> unfollowUser(String targetUid) async {
    if (!AuthService.isLoggedIn) return;
    final currentUid = AuthService.uid;

    try {
      final batch = _firestore.batch();
      
      final followingRef = _firestore.collection('users').doc(currentUid).collection('following').doc(targetUid);
      batch.delete(followingRef);

      final followerRef = _firestore.collection('users').doc(targetUid).collection('followers').doc(currentUid);
      batch.delete(followerRef);

      await batch.commit();
      print('[SocialService] Berhasil unfollow user $targetUid');
    } catch (e) {
      print('[SocialService] Error unfollowUser: $e');
    }
  }

  /// Mengambil daftar followers berserta data profilnya
  static Future<List<Map<String, dynamic>>> getFollowers(String uid) async {
    try {
      final snap = await _firestore.collection('users').doc(uid).collection('followers').orderBy('timestamp', descending: true).get();
      List<Map<String, dynamic>> followers = [];
      for (var doc in snap.docs) {
        final userSnap = await _firestore.collection('users').doc(doc.id).get();
        if (userSnap.exists) {
          final docData = userSnap.data() as Map<String, dynamic>;
          final data = docData.containsKey('profile') ? Map<String, dynamic>.from(docData['profile'] as Map) : <String, dynamic>{};
          data['uid'] = doc.id; 
          followers.add(data);
        }
      }
      return followers;
    } catch (e) {
      print('[SocialService] Error getFollowers: $e');
      return [];
    }
  }

  /// Mengambil daftar following berserta data profilnya
  static Future<List<Map<String, dynamic>>> getFollowing(String uid) async {
    try {
      final snap = await _firestore.collection('users').doc(uid).collection('following').orderBy('timestamp', descending: true).get();
      List<Map<String, dynamic>> following = [];
      for (var doc in snap.docs) {
        final userSnap = await _firestore.collection('users').doc(doc.id).get();
        if (userSnap.exists) {
          final docData = userSnap.data() as Map<String, dynamic>;
          final data = docData.containsKey('profile') ? Map<String, dynamic>.from(docData['profile'] as Map) : <String, dynamic>{};
          data['uid'] = doc.id;
          following.add(data);
        }
      }
      return following;
    } catch (e) {
      print('[SocialService] Error getFollowing: $e');
      return [];
    }
  }

  /// Menghapus follower dari daftar pengikut (Remove Follower)
  static Future<void> removeFollower(String followerUid) async {
    if (!AuthService.isLoggedIn) return;
    final currentUid = AuthService.uid;

    try {
      final batch = _firestore.batch();
      
      final followerRef = _firestore.collection('users').doc(currentUid).collection('followers').doc(followerUid);
      batch.delete(followerRef);

      final followingRef = _firestore.collection('users').doc(followerUid).collection('following').doc(currentUid);
      batch.delete(followingRef);

      await batch.commit();
      print('[SocialService] Berhasil menghapus follower $followerUid');
    } catch (e) {
      print('[SocialService] Error removeFollower: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SOCIAL FEED, LIKES, AND COMMENTS
  // ─────────────────────────────────────────────────────────────────────────────

  /// Mempublikasikan aktivitas (Workout) ke Feed Publik
  static Future<void> publishWorkoutToFeed(Map<String, dynamic> workoutMap) async {
    if (!AuthService.isLoggedIn) return;
    final uid = AuthService.uid;

    try {
      // Ambil data profil pengguna saat ini
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      final name = userData['name'] ?? 'Athlete';
      final username = userData['username'] ?? 'athlete';
      final photoUrl = userData['photoUrl'];

      // Generate postId (bisa pakai ID workout ditambah UID atau auto-id)
      final docRef = _firestore.collection('feed_posts').doc();
      
      final postData = {
        'postId': docRef.id,
        'uid': uid,
        'authorName': name,
        'authorUsername': username,
        'authorPhotoUrl': photoUrl,
        'workoutData': workoutMap,
        'timestamp': FieldValue.serverTimestamp(),
        'likedBy': [],
        'commentsCount': 0,
      };

      await docRef.set(postData);
      print('[SocialService] Berhasil publish workout ke Feed.');
    } catch (e) {
      print('[SocialService] Error publishWorkoutToFeed: $e');
    }
  }

  /// Mengambil Feed Posts dengan pagination (10 post per halaman)
  /// [startAfter]: DocumentSnapshot untuk cursor pagination (null = mulai dari awal)
  static Future<Map<String, dynamic>> getFeedPosts({
    DocumentSnapshot? startAfter,
    int limit = 10,
  }) async {
    if (!AuthService.isLoggedIn) return {'posts': [], 'lastDoc': null};
    final uid = AuthService.uid;

    try {
      // 1. Ambil daftar UID yang kita follow
      final followingSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('following')
          .get();
      final List<String> followingUids =
          followingSnap.docs.map((d) => d.id).toList();
      followingUids.add(uid); // Masukkan post sendiri ke dalam feed

      // 2. Build query dengan orderBy + limit + optional startAfter
      Query query = _firestore
          .collection('feed_posts')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final postsSnap = await query.get();

      List<Map<String, dynamic>> feed = [];
      for (var doc in postsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final postUid = data['uid'] as String;
        // Filter: hanya post dari following atau diri sendiri
        if (followingUids.contains(postUid)) {
          feed.add(data);
        }
      }

      // Return both posts and last document (for next page cursor)
      final lastDoc = postsSnap.docs.isNotEmpty ? postsSnap.docs.last : null;
      return {'posts': feed, 'lastDoc': lastDoc};
    } catch (e) {
      print('[SocialService] Error getFeedPosts: $e');
      return {'posts': [], 'lastDoc': null};
    }
  }

  /// Toggle Like pada suatu Post
  static Future<void> toggleLike(String postId, List<dynamic> currentLikedBy) async {
    if (!AuthService.isLoggedIn) return;
    final uid = AuthService.uid;
    final postRef = _firestore.collection('feed_posts').doc(postId);

    try {
      final hasLiked = currentLikedBy.contains(uid);
      if (hasLiked) {
        // Unlike
        await postRef.update({
          'likedBy': FieldValue.arrayRemove([uid])
        });
      } else {
        // Like
        await postRef.update({
          'likedBy': FieldValue.arrayUnion([uid])
        });

        // Coba kirim notifikasi ke pembuat post (jika bukan diri sendiri)
        final postSnap = await postRef.get();
        if (postSnap.exists) {
          final authorUid = postSnap.data()!['uid'];
          if (authorUid != uid) {
            final myDoc = await _firestore.collection('users').doc(uid).get();
            if (myDoc.exists) {
              final myData = myDoc.data()!;
              final myProfile = myData.containsKey('profile')
                  ? Map<String, dynamic>.from(myData['profile'] as Map)
                  : myData;
              final myName = myProfile['name'] ?? 'Seseorang';
              await NotificationService.addNotification(
                authorUid,
                title: 'Suka Baru',
                body: '$myName menyukai aktivitas Anda.',
                type: 'like',
                relatedUid: uid,
                relatedPhotoUrl: myProfile['photoUrl'],
              );
              
              await _triggerVercelFCM(authorUid, 'Suka Baru', '$myName menyukai aktivitas Anda.');
            }
          }
        }
      }
    } catch (e) {
      print('[SocialService] Error toggleLike: $e');
    }
  }

  /// Menambahkan Komentar
  static Future<void> addComment(String postId, String text) async {
    if (!AuthService.isLoggedIn || text.trim().isEmpty) return;
    final uid = AuthService.uid;

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      final profile = userData.containsKey('profile')
          ? Map<String, dynamic>.from(userData['profile'] as Map)
          : userData;
      final name = profile['name'] ?? 'Athlete';
      final photoUrl = profile['photoUrl'];

      final commentRef = _firestore.collection('feed_posts').doc(postId).collection('comments').doc();
      
      await _firestore.runTransaction((transaction) async {
        final postRef = _firestore.collection('feed_posts').doc(postId);
        final postSnap = await transaction.get(postRef);
        
        if (!postSnap.exists) throw Exception('Post tidak ditemukan');
        
        final newCount = (postSnap.data()!['commentsCount'] ?? 0) + 1;
        
        transaction.set(commentRef, {
          'commentId': commentRef.id,
          'uid': uid,
          'authorName': name,
          'authorPhotoUrl': photoUrl,
          'text': text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        transaction.update(postRef, {'commentsCount': newCount});
      });

      // Kirim notifikasi
      final postSnap = await _firestore.collection('feed_posts').doc(postId).get();
      if (postSnap.exists) {
        final authorUid = postSnap.data()!['uid'];
        if (authorUid != uid) {
          await NotificationService.addNotification(
            authorUid,
            title: 'Komentar Baru',
            body: '$name mengomentari: "${text.trim()}"',
            type: 'comment',
            relatedUid: uid,
            relatedPhotoUrl: photoUrl,
          );
          
          await _triggerVercelFCM(authorUid, 'Komentar Baru', '$name mengomentari: "${text.trim()}"');
        }
      }

    } catch (e) {
      print('[SocialService] Error addComment: $e');
    }
  }

  /// Mengambil komentar sebuah post
  static Future<List<Map<String, dynamic>>> getComments(String postId) async {
    try {
      final snap = await _firestore
          .collection('feed_posts')
          .doc(postId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      print('[SocialService] Error getComments: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // PUBLIC PROFILE
  // ─────────────────────────────────────────────────────────────────────────────

  /// Mengecek apakah current user sudah follow targetUid
  static Future<bool> checkIsFollowing(String targetUid) async {
    if (!AuthService.isLoggedIn) return false;
    final currentUid = AuthService.uid;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('following')
          .doc(targetUid)
          .get();
      return doc.exists;
    } catch (e) {
      print('[SocialService] Error checkIsFollowing: $e');
      return false;
    }
  }

  /// Mendapatkan data profil pengguna lain
  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final docData = doc.data()!;
        final data = docData.containsKey('profile') ? Map<String, dynamic>.from(docData['profile'] as Map) : <String, dynamic>{};
        data['uid'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      print('[SocialService] Error getUserProfile: $e');
      return null;
    }
  }

  /// Mendapatkan semua Feed Posts milik seorang pengguna
  static Future<List<Map<String, dynamic>>> getUserPosts(String uid) async {
    try {
      final snap = await _firestore
          .collection('feed_posts')
          .where('uid', isEqualTo: uid)
          .get();
      
      final posts = snap.docs.map((d) => d.data()).toList();
      
      // Sort lokal agar tidak perlu composite index di Firestore
      posts.sort((a, b) {
        final aTime = a['timestamp']?.toDate() ?? DateTime.now();
        final bTime = b['timestamp']?.toDate() ?? DateTime.now();
        return bTime.compareTo(aTime); // descending
      });
      
      return posts;
    } catch (e) {
      print('[SocialService] Error getUserPosts: $e');
      return [];
    }
  }
}
