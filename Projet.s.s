#=============================================================================
# Projet Traitement d'images
# Architecture des ordinateurs
# L2S3 - 2020/2021
# Saday Arhun / Nassr Ahmed
#=============================================================================





#=============================================================================
# Partie donnees
#=============================================================================
.data
  

  texte_demande: .asciiz "Veuillez entrer le nom du fichier (extension y compris) : "
  texte_attente: .asciiz "Veuillez patienter pendant que l'image est traite.\n"
  texte_erreur_ouverture: .asciiz "Erreur lors de l'ouverture du fichier.\n"
  texte_erreur_bmp: .asciiz "Le fichier indique n'est pas au format bmp.\n"
  texte_succes: .asciiz "L'image traitee a ete enregistree avec succes!\n"
  texte_erreur_lecture: .asciiz "Erreur lors de la lecture du fichier.\n"
  suffix_contour: .asciiz "Contour"
  char_retour: .asciiz "\n"
  char_fin_chaine: .asciiz "\0"
  char_point: .asciiz "."
  signature_buffer: .asciiz "AA"
  signature_bmp: .asciiz "BM"

  buffer_entier: .space 4 
  nom_fichier_entree: .space 32 
  nom_fichier_sortie: .space 39 
  seuil_valeur: .word 140

  .align 2
  entete_profondeur: .space 4
  entete_largeur: .space 4
  entete_hauteur:	.space 4
  entete_nombre_couleurs: .space 4
  entete_resolution_verticale: .space 4
  entete_resolution_horizontale: .space 4





#=============================================================================
# Fonction main
#=============================================================================
.text
.globl __start

__start:
  # On affiche le message pour demander le nom du fichier
  la	  	$a0 texte_demande
  jal	  	afficher_chaine

  # On recupere le nom du fichier 
  la		  $a0 nom_fichier_entree # $a0 = adresse de la chaine qui va contenir le nom du fichier
  jal		  demander_nom_fichier

  # On ouvre le descripteur de fichier en mode lecture
  li	  	$a1 0 # $a1 = flag pour le syscall (0 = mode lecture)
  jal		  ouvrir_fichier
  move		$s0 $v0 # $s0 = descripteur de fichier 

  # On lis la signature du fichier 
  move		$a0 $s0 # $a0 = descripteur de fichier
  la		  $a1 signature_buffer # $a1 = adresse de la chaine qui va contenir la signature
  li		  $a2 2 # $a2 = 2 pour lire deux octets
  jal		  lire_n_octets

  # On verifie la signature du fichier
  la	  	$a2 signature_bmp # $a2 = adresse de la chaine "BM"
  jal	  	verifier_signature

  # On affiche le texte qui demande a l'utilisateur d'attendre
  la		  $a0 texte_attente
  jal	  	afficher_chaine

  # On lis et on sauvegarde les differentes parties du fichier en memoire
  move    $a0 $s0 # $a0 = descripteur de fichier
  jal		  sauvegarder_fichier

  # On procede au traitement de l'image 
  jal		  traiter_image

  # On cree le nom du fichier de sortie avec le suffix "Contour"
  la	  	$a0 nom_fichier_entree # $a0 = adresse de la chaine qui contient le nom du fichier 
  la		  $a1 nom_fichier_sortie # $a1 = adresse de la chaine qui va contenir le nouveau nom du fichier
  jal		  creer_nom_sortie

  # On ecris le fichier de sortie 
  la		  $a0 nom_fichier_sortie # $a0 = adresse de la chaine qui contient le nom du fichier 
  li	  	$a1 1 # $a1 = flag pour le syscall (1 = mode ecriture)
  jal		  ouvrir_fichier
  move		$s0 $v0 
  move		$a0 $s0 # $a0 = descripteur de fichier
  move		$a1 $s3 # $a1 = adresse de la matrice
  jal		  ecrire_fichier

  # On affiche le texte de succes
  la		  $a0 texte_succes
  jal		  afficher_chaine

  # On quitte le programme 
  la		  $a0 texte_succes
  j		    quitter_programme





#=============================================================================
#
# Fonctions pour lire le fichier bmp
#
#=============================================================================

#=============================================================================
# Lis N octets du fichier
# Parametres: 
#   $a0: descripteur de fichier
#	  $a1: adresse du buffer ou stocker le resultat 
#	  $a2: nombre d'octets a lire
#=============================================================================
lire_n_octets:
  # Prologue
  subu		$sp $sp 8
  sw	  	$ra 0($sp)
  sw		  $v0 4($sp)

  # Corps
  li	  	$v0 14 # appel systeme 14 = lire depuis fichier
  syscall

  blt		  $v0 0 erreur_lireFichier # erreur si v0 < 0
  j		    epilogue_lireNoctets
  
  erreur_lireFichier:
    la		$a0 texte_erreur_lecture
    jal		afficher_chaine
    jal		quitter_programme

  # Epilogue
  epilogue_lireNoctets:
    lw		$ra 0($sp)
    lw		$v0 4($sp) 
    addi	$sp $sp 8
    jr		$ra

#=============================================================================
# Lis et sauvegarde certaines elements de l'entete dans des buffers
# Parametres: 
#   $a0: descripteur de fichier
#=============================================================================
lire_entete:
  # Prologue
  subu		$sp $sp 8
  sw	  	$ra 0($sp)
  sw		  $a1 4($sp)

  # Corps
  # On lis la taille totale du fichier
  la		  $a1 buffer_entier
  li		  $a2 4
  jal		  lire_n_octets

  # On lis le champ reserve
  la		  $a1 buffer_entier
  li		  $a2 4
  jal		  lire_n_octets

  # On lis l'offset
  la	  	$a1 buffer_entier
  li	  	$a2 4
  jal	  	lire_n_octets
  
  # On lis la taille de l'entete
  la		  $a1 buffer_entier
  li		  $a2 4
  jal		  lire_n_octets

  # On lis et on sauvegarde la largeur de l'image (nbr de pixels horizontalement)
  la	  	$a1 entete_largeur
  li	  	$a2 4
  jal	  	lire_n_octets

  # On lis et on sauvegarde la hauteur de l'image (nbr de pixels verticalement)
  la	  	$a1 entete_hauteur
  li		  $a2 4
  jal		  lire_n_octets

  # On lis et on sauvegarde le nombre de plans (= 1)
  la	  	$a1 signature_buffer 
  li	  	$a2 2
  jal		  lire_n_octets
  
  # On lis et on sauvegarde la profondeur de codage de la couleur
  la	  	$a1 entete_profondeur
  li	  	$a2 2
  jal	  	lire_n_octets

  # On lis la methode de compression de l'image
  la		  $a1 buffer_entier
  li	    $a2 4
  jal		  lire_n_octets

  # On lis la taille totale de l'image
  la	  	$a1 buffer_entier
  li		  $a2 4
  jal		  lire_n_octets

  # On lis et on sauvegarde la resolution horizontale (nbr de pixels par metre horizontalement)
  la		  $a1 entete_resolution_horizontale
  li		  $a2 4
  jal		  lire_n_octets

  # On lis et on sauvegarde la resolution verticale (nbr de pixels par metre verticalement)
  la		  $a1 entete_resolution_verticale
  li		  $a2 4
  jal		  lire_n_octets

  # On lis et on sauvegarde le nombre de couleurs de la palette
  la	  	$a1 entete_nombre_couleurs
  li		  $a2 4
  jal		  lire_n_octets

  # On lis le nombre de couleurs importantes de la palette
  la		  $a1 buffer_entier
  li		  $a2 4
  jal	  	lire_n_octets

  # Epilogue
  lw	  	$ra 0($sp)
  lw		  $a1 4($sp)
  addi		$sp $sp 8
  jr		  $ra

#=============================================================================
# On lis et on sauvegarde la palette de l'image
# Parametres: 
#   $a0: descripteur de fichier
# Retour: 
#   $v0: adresse de l'espace alloue dans le tas qui contient la palette
#=============================================================================
lire_palette:
  # Prologue
  subu		$sp $sp 20
  sw	  	$ra 0($sp)
  sw	  	$a0 4($sp)
  sw		  $a1 8($sp)
  sw	    $s0 12($sp)
  sw		  $s1 16($sp)

  # Corps
  # On lis le nombre de couleurs
  la		  $a1 entete_nombre_couleurs # $a1 = adresse du buffer qui contient le nombre de couleurs
  lw	  	$s1 0($a1)  # $s1 = nombre de couleurs

  # On alloue un espace memoire sur le tas 
  li	  	$t0 3 
  mul	  	$a0 $s1 $t0 # $a0 = $s1 * 3 car il y a trois composants (rouge, vert, bleu)
  li	  	$v0 9 # appel systeme 9 : allouer memoire sur le tas 
  syscall 
  move		$s0 $v0
  lw	  	$a0 4($sp) # $a0 = descripteur de fichier
  la	  	$a1 buffer_entier
  
  boucle_lirePalette:
    beq		  $s1 $zero finBoucle_lirePalette # on quitte la boucle si on a recupere toutes les couleurs
    li		  $a2 4
    jal		  lire_n_octets # $a1 = l'octet qu'on vient de lire

    lb		  $t0 0($a1) # $t0 = composante rouge
    lb		  $t1 1($a1) # $t1 = composante verte
    lb		  $t2 2($a1) # $t2 = composante bleue
    sb		  $t0 0($s0) # $s0 = composante rouge
    sb		  $t1 1($s0) # $s0+1 = composante verte
    sb		  $t2 2($s0) # $s0+2 = composante bleue

    addi	  $s0 $s0 3 # on se deplace de 3 octets dans l'espace memoire alloue de la palette
    subu	  $s1 $s1 1 # on decremente le nbr de couleurs
    j		    boucle_lirePalette # on boucle

  finBoucle_lirePalette:
    # Epilogue
    lw		  $ra 0($sp)
    lw		  $a0 4($sp)
    lw		  $a1 8($sp)
    lw		  $s0 12($sp)
    lw		  $s1 16($sp)
    addi	  $sp $sp 20
    jr		  $ra

#=============================================================================
# On lis et on sauvegarde la matrice de l'image
# Parametres: 
#   $a0: descripteur de fichier
# Retour: 
#   $v0: adresse de l'espace alloue dans le tas qui contient la matrice
#	  $v1: taille de la matrice en octets 
#=============================================================================
lire_matrice:
  # Prologue
  subu	  $sp $sp 36
  sw		  $ra 0($sp)
  sw	  	$a0 4($sp)
  sw		  $a1 8($sp)
  sw	  	$a2 12($sp)
  sw	  	$s0 16($sp)
  sw	  	$s1 20($sp)
  sw	  	$s2 24($sp)
  sw	  	$s3 28($sp)
  sw	  	$s4 32($sp)

  # Corps
  la		  $s1 entete_largeur 
  lw		  $s0 0($s1) # $s0 = largeur de l'image
  la		  $s1 entete_profondeur 
  lw		  $s2 0($s1) # $s2 = profondeur de l'image
  la	  	$s1 entete_hauteur 
  lw		  $s4 0($s1) # $s4 = hauteur de l'image
  mul		  $s1 $s0 $s2 # $s1 = $s0 * $s2 (largeur * profondeur)
  li		  $s3 8 # $s3 = 8 
  div		  $s1 $s3
  mfhi	  $s1 # $s1 = $s1 % $s3 (largeur * profondeur % 8)
  mflo	  $s3 # $s3 = $s1 / $s3 (largeur * profondeur / 8)
  move	  $t0 $s4 # $t0 = hauteur de l'image (nbr de lignes)
  move	  $t1 $s3 # $t1 = nbr d'octets par ligne
  move	  $t2 $s1 # $t2 = nbr d'octet a lire en plus a chaque fin de ligne

  li		  $v0 9 # appel systeme 9 : allouer memoire sur le tas 
  mul		  $a0 $t0 $t1
  move	  $v1 $a0
  syscall

  move	  $t3 $v0 # $t3 = adresse de l'espace alloue
  lw		  $a0 4($sp) # $a0 = descripteur de fichier
  move	  $a2 $t1 # $a2 = nbr d'octets a lire par ligne

  boucle_lireMatrice:
    # Si nbr de lignes = 0, on a fini 
    # sinon on lis et on soustrait 1 
    beqz		$t0 finBoucle_lireMatrice
    move		$a1 $t3 # $a1 adresse de l'espace alloue
    jal		  lire_n_octets
    add		  $t3 $t3 $t1 # on se deplace de $t1 octets dans $t3
    beqz	 	$t2 continuer_lireMatrice 
    la		  $a1 buffer_entier
    move		$a2 $t2
    jal		  lire_n_octets
    move		$a2 $t1

  continuer_lireMatrice:
    subu		$t0 $t0 1
    j	    	boucle_lireMatrice

  finBoucle_lireMatrice:
    # Epilogue
    lw		  $ra 0($sp)
    lw		  $a0 4($sp)
    lw		  $a1 8($sp)
    lw		  $a2 12($sp)
    lw		  $s0 16($sp)
    lw		  $s1 20($sp)
    lw		  $s2 24($sp)
    lw		  $s3 28($sp)
    lw		  $s4 32($sp)
    addi		$sp $sp 36
    jr		  $ra





#=============================================================================
#
# Fonctions pour ecrire le fichier bmp
#
#=============================================================================

#=============================================================================
# Appelle les differentes fonctions pour appliquer le filtre de Sobel
#=============================================================================

traiter_image: 
  # Prologue
  subu		$sp $sp 4
  sw		  $ra 0($sp)
  
  # Corps
  # On alloue des espaces memoires correspondants aux matrices Gx et Gy
  move		$a0 $s5 # $a0 = taille de la matrice image en octets
  li		  $v0 9 # appel systeme 9 = allouer memoire sur le tas
  syscall
  move		$s3 $v0 # $s3 = adresse de Gx

  li		  $v0 9 # appel systeme 9 = allouer memoire sur le tas
  syscall
  move		$s4 $v0 # $s4 = adresse de Gy

  # On calcule les matrices Gx et Gy
  move		$a0 $s2 # $a0 = adresse de la matrice image
  lw	  	$a2 seuil_valeur # $a2 = seuil inférieur
  
  # On calcule Gx
  move		$a1 $s3 # $a1 = adresse de Gx 
  li	  	$a3 0 # $a3 = 0 pour calculer matrice horizontal 
  jal		  calculer_matrice

  # On calcule Gy
  move		$a1 $s4 # $a1 = adresse de Gy 
  li		  $a3 1 # $a3 = 1 pour calculer matrice horizontal
  jal		  calculer_matrice

  # On additionne les deux matrices (resultat dans Gx)
  move		$a0 $s3 # $a0 = adresse de Gx 
  move		$a1 $s4 # $a0 = adresse de Gy 
  jal	  	ajouter_deux_matrices

  # Epilogue
  lw		  $ra 0($sp)
  addi		$sp $sp 4
  jr		  $ra

#=============================================================================
# Defini le nouveau nom du fichier avec le suffix "Contour"
# Parametres: 
#   $a0: adresse de la chaine de caracteres qui contient le nom du fichier
#	  $a1: adresse de la chaine qui va contenir le nouveau nom
#=============================================================================
creer_nom_sortie:
  # Prologue
  subu		$sp $sp 24
  sw		  $ra 0($sp)
  sw	  	$a0 4($sp)
  sw		  $a1 8($sp)
  sw		  $a2 12($sp)
  sw		  $a3 16($sp)
  sw		  $s0 20($sp)

  # Corps
  la		  $a2 char_point # $a2 = "\0"
  lb		  $t9 0($a2) # $t9 = "\0" sur 1 octet

  boucle_trouverPointDansNom:
    lb		  $t1 0($a0) # on lit un caractere dans $a0 (le nom du fichier)
    beq		  $t1 $t9 ajouter_suffix # si c'est un "." on passe a ajouter_suffix
    sb		  $t1 0($a1) # si c'est pas le cas on le copie dans $a1
    addi		$a0 $a0 1 # on se deplace d'un octet dans $a0
    addi		$a1 $a1 1 # on se deplace d'un octet dans $a1
    j		    boucle_trouverPointDansNom # on boucle

  ajouter_suffix:
    move		$s0 $a0 # $s0 = emplacement de "."
    la		  $a3 suffix_contour # $a3 = adresse de la chaine contenant "Contour" 
    li	  	$t2 0 # $t2 = compteur de caracteres
    li		  $t3 7 # $t3 = limite de caracteres (7 pour Contour)

  boucle_ecrireSuffix:
    beq		  $t2 $t3 finBoucle_ecrireSuffix # si limite atteinte, on quitte la boucle
    lb		  $t1 0($a3) # sinon on lit un caractere dans $a3 (chaine "Contour")
    sb		  $t1 0($a1) # on l'ecrit dans $a1
    addi		$t2 $t2 1 # on incremente le compteur de caracteres
    addi		$a1 $a1 1 # on se deplace d'un octet dans $a1
    addi		$a3 $a3 1 # on se deplace d'un octet dans $a3
    j		    boucle_ecrireSuffix # on boucle

  finBoucle_ecrireSuffix:
    lb		  $t1 0($a0) # on recupere "."
    sb		  $t1 0($a1) # on l'ecrit dans $a1
    lb		  $t1 1($a0) # on recupere "b"
    sb		  $t1 1($a1) # on l'ecrit dans $a1
    lb		  $t1 2($a0) # on recupere "m"
    sb		  $t1 2($a1) # on l'ecrit dans $a1
    lb		  $t1 3($a0) # on recupere "p"
    sb		  $t1 3($a1) # on l'ecrit dans $a1
    la		  $a2 char_fin_chaine # $a2 = adresse de la chaine "\n"
    lb		  $t9 0($a2) # $t9 = "\0" sur 1 octet
    sb		  $t9 4($a1) # on ecrit "\0" a la		fin de $a1 (nouveau nom)

    # Epilogue
    lw		$ra 0($sp)
    lw		$a0 4($sp)
    lw		$a1 8($sp)
    lw		$a2 12($sp)
    lw		$a3 16($sp)
    lw		$s0 20($sp)
    addi	$sp $sp 24
    jr		$ra

#=============================================================================
# Appelle les fonctions pour sauvegarder en memoire les differentes
# parties du fichier .bmp (entete, palette, image)
# Parametres: 
#   $a0: descripteur de fichier
#=============================================================================
sauvegarder_fichier:
  # Prologue 
  subu		$sp $sp 4
  sw	  	$ra 0($sp)

  # Corps  
  # On lis et on sauvegarde l'entete du fichier ".bmp" en memoire
  jal		  lire_entete

  # On lis et on sauvegarde la palette en memoire
  jal		  lire_palette
  move		$s1 $v0 # $s1 = adresse de la palette en memoire

  # On lis et on sauvegarde la matrice en memoire
  jal	  	lire_matrice
  move		$s2 $v0 # $s2 = adresse de la matrice image en memoire
  move    $s5 $v1 # $s5 = taille de la matrice en octets

  # On ferme le descripteur de fichier
  move    $a0 $s0 # $a0 = descripteur de fichier
  li		  $v0 16 # appel systeme 16 = fermer fichier
  syscall

  # Epilogue
  lw		  $ra 0($sp)
  addi		$sp $sp 12
  jr	  	$ra

#=============================================================================
# Ecris les entetes du fichier
# Parametres: 
#   $a0: descripteur de fichier
#	  $a1: adresse du premier octet de la matrice calculee
#=============================================================================
ecrire_fichier:
  # Prologue
  subu		$sp $sp 16
  sw	  	$v0 0($sp)
  sw		  $a1 4($sp)
  sw	  	$a2 8($sp)
  sw	  	$ra 12($sp)

  # Corps
  move		$s1 $a1

  # On recupere tout les donnees qu'on a sauvegarde en memoire
  la		  $a1 entete_largeur
  lw		  $t0 0($a1)
  la		  $a1 entete_hauteur
  lw		  $t1 0($a1)
  la		  $a1 entete_profondeur
  lw		  $t2 0($a1)
  la		  $a1 entete_resolution_horizontale
  lw		  $t3 0($a1)
  la		  $a1 entete_resolution_verticale
  lw		  $t4 0($a1)

  li		  $t5 4
  div		  $t0 $t5
  mfhi		$t6
  add		  $t5 $t0 $t6
  mul		  $t5 $t5 $t1
  addi		$t6 $t5 1078 # 62 = entetes + palette 2 couleurs
  
  # On ecrit la signature
  la		  $a1 signature_bmp
  li		  $a2 2 # $a2 = 2 caracteres a ecrire
  li		  $v0 15 # appel systeme 10 = ecrire a un fichier
  syscall

  # On ecrit la taille totale
  li		  $v0 15 # appel systeme 10 = ecrire a un fichier
  la		  $a1 entete_hauteur
  lw		  $t1 0($a1)
  li		  $a2 4 # $a2 = 4 caracteres a ecrire
  syscall

  # On ecrit le champ reserve
  li		  $t6 0
  sw		  $t6 0($a1)
  li		  $v0 15 # appel systeme 10 = ecrire a un fichier
  syscall

  # On ecrit l'offset
  li		  $t6 1078
  sw		  $t6 0($a1)
  li		  $v0 15 # appel systeme 10 = ecrire a un fichier
  syscall

  # On ecrit la taille de l'entete
  li		  $t6 40
  sw		  $t6 0($a1)
  li		  $v0 15 # appel systeme 10 = ecrire a un fichier
  syscall

  # On ecrit la largeur de l'image
  sw		  $t0 0($a1)
  li		  $v0 15 # appel systeme 10 = ecrire a un fichier
  syscall

  # On ecrit la hauteur de l'image
  sw		  $t1 0($a1)
  li	  	$v0 15 # appel systeme 10 = ecrire a un fichier
  syscall

  # On ecrit le nombre de plans et la profondeur de codage de la couleur
  li		  $t6 1
  sh      $t6 0($a1)
  li		  $t6 8
  sh      $t6 2($a1)
  li		  $v0 15 # appel systeme 10 = ecrire a un fichier
  syscall

  # On ecrit la methode de compression
  li		  $t6 0
  sw		  $t6 0($a1)
  li		  $v0 15 # appel systeme 10 = ecrire a un fichier
  syscall

  # On ecrit la taille totale de l'image
  sw	  	$t5 0($a1)
  li	  	$v0 15 # appel systeme 10 = ecrire a un fichier
  syscall

  # On ecrit la resolution horizontale
  sw		  $t3 0($a1)
  li		  $v0 15 # appel systeme 10 = ecrire a un fichier
  syscall

  # On ecrit la resolution verticale
  sw		  $t4 0($a1)
  li	  	$v0 15 # appel systeme 10 = ecrire a un fichier
  syscall

  # On ecrit le nombre de couleurs de la palette
  li		  $t6 256
  sw	  	$t6 0($a1)
  li	  	$v0 15 # appel systeme 10 = ecrire a un fichier
  syscall

  # On ecrit le nombre de couleurs importantes de la palette
  li		  $v0 15 # appel systeme 10 = ecrire a un fichier
  syscall

  # On fais une boucle pour ecrire la palette de l'image
  li	  	$t8 0
  li		  $t7 256

  boucle_palette:
    move		$t6 $t8
    beq	  	$t8 $t7 finBoucle_palette # on a fini si $t8 = 256
    sb		  $t6 0($a1)
    sb	  	$t6 1($a1)
    sb		  $t6 2($a1)
    li		  $t6 0
    sb		  $t6 3($a1)
    li		  $v0 15 # appel systeme 10 = ecrire a un fichier
    syscall
    addi		$t8 $t8 1
    j		    boucle_palette

  finBoucle_palette:
    # On ecrit la matrice correspondant a l'image dans le fichier
    lw		  $a1 4($sp) # $a1 = adresse de la matrice 
    move		$a2 $t5 # $a2 = nombre d'octets a ecrire (taille de l'image)
    li		  $v0 15 # appel systeme 10 = ecrire a un fichier
    syscall

    # On ferme le descripteur de fichier
    move    $a0 $s0 # $a0 = descripteur de fichier
    li		  $v0 16 # appel systeme 16 = fermer fichier
    syscall

    # Epilogue
    lw		  $v0 0($sp)
    lw		  $a1 4($sp)
    lw		  $a2 8($sp)
    lw		  $ra 12($sp)
    addi		$sp $sp 16
    jr	  	$ra

#=============================================================================
# Lis une case a l'indice [i][j] de la matrice
# Parametres: 
#   $a0: matrice
#   $a1: ligne i
#   $a2: colonne j
# Retour: 
#   $v0: valeur a l'indice [i][j] de la matrice
#=============================================================================
lire_case:
  # Prologue
  subu		$sp $sp 12
  sw		  $s0 0($sp)
  sw		  $s1 4($sp)
  sw		  $s2 8($sp)

  # Corps
  move		$s0 $a0 # $s0 = adresse temporaire
  la		  $s1 entete_largeur # $s1 adresse de la largeur 
  lw		  $s2 0($s1) # $s2 = largeur en pixels
  mul	    $s1 $s2 $a1 # $s1 = largeur * i
  add	    $s1 $s1 $a2 # $s1 = $s1 + j
  add	    $s0 $s0 $s1 # $s0 = $s0 + $s1
  lbu     $v0 0($s0) # $v0 = la valeur a l'indice [i][j]

  # Epilogue
  lw		  $s0 0($sp)
  lw		  $s1 4($sp)
  lw		  $s2 8($sp)
  addi		$sp $sp 12
  jr	  	$ra

#=============================================================================
# Modifie un element de la matrice
# Parametres: 
#   $a0: adresse de la matrice
#   $a1: ligne i
#   $a2: colonne j
#   $a3: element a ecrire
#=============================================================================
modifier_case:
  # Prologue
  subu		$sp $sp 12
  sw		  $s0 0($sp)
  sw	  	$s1 4($sp)
  sw	  	$s2 8($sp)

  # Corps
  move		$s0 $a0 # $s0 = adresse temporaire
  la		  $s1 entete_largeur # $s1 adresse de la largeur 
  lw		  $s2 0($s1) # $s2 = largeur en pixels
  mul		  $s1 $s2 $a1 # $s1 = largeur * i
  add		  $s1 $s1 $a2 # $s1 = $s1 + j
  add		  $s0 $s0 $s1 # $s0 = $s0 + $s1
  sb		  $a3 0($s0) # on ecrit $a3 a l'adresse $s0

  # Epilogue
  lw		  $s0 0($sp)
  lw		  $s1 4($sp)
  lw		  $s2 8($sp)
  addi		$sp $sp 12
  jr	  	$ra

#=============================================================================
# Calcule le gradient horizontal ou vertical
# Parametres: 
#   $a0: adresse de la matrice M
#	  $a1: ligne i
#	  $a2: colonne j
#   $a3: si $a3 = 0 on calcule le gradient horizontal, sinon vertical
# Retour: 
#   $v0: gradient
#=============================================================================
calculer_gradient:
  # Prologue
  subu		$sp $sp 16
  sw	    $s1 0($sp)
  sw	    $a2 4($sp)
  sw	    $ra 8($sp)
  sw	    $a1 12($sp)

  # Corps 
  bge $a3 1 gradient_vertical # on passe au calcul du gradient vertical si $a3 = 1

  gradient_horizontal:
    move		$s1 $a1
    # Formule : Gx(i, j) = M(i-1, j-1) - M(i-1, j+1) + 2 * M(i, j-1) - 2 * M(i, j+1) + M(i+1, j-1) - M(i+1, j+1)
    subu		$a1 $a1 1 # i-1
    subu		$a2 $a2 1 # j-1
    jal		  lire_case

    move		$t0 $v0 # gradient = M(i-1, j-1)
    addi		$a2 $a2 2 # j+1
    jal		  lire_case

    sub		  $t0 $t0 $v0 # gradient = gradient - M(i-1, j+1)
    addi		$a1 $a1 1 # i
    subu		$a2 $a2 2 # j-1
    jal		  lire_case

    li		  $t1 2
    mul		  $v0 $v0 $t1
    add		  $t0 $t0 $v0 # gradient = gradient + 2 * M(i, j-1)
    addi		$a2 $a2 2 # j+1
    jal	  	lire_case

    mul		  $v0 $v0 $t1
    sub		  $t0 $t0 $v0 # gradient = gradient - 2 * M(i, j+1)
    addi		$a1 $a1 1 # i+1
    subu		$a2 $a2 2 # j-1
    jal		  lire_case

    add		  $t0 $t0 $v0 # gradient = gradient + M(i+1, j-1)
    addi		$a2 $a2 2 # j+1
    jal		  lire_case

    sub		  $t0 $t0 $v0 # gradient = gradient - M(i+1, j+1)
    move		$v0 $t0 # $v0 = gradient
    move		$a1 $s1
  
    j epilogue_calculerGradient

  gradient_vertical:
    move		$s1 $a1
    # Formule : Gy(i, j) = M(i-1, j-1) + 2 * M(i-1, j) + M(i-1, j+1) - M(i+1, j-1) - 2 * M(i+1, j) - M(i+1, j+1)
    subu		$a1 $a1 1 # i-1
    subu		$a2 $a2 1 # j-1
    jal		  lire_case

    move		$t0 $v0 # gradient = M(i-1, j-1)
    addi		$a2 $a2 1 # j
    jal		  lire_case

    li	    $t1 2
    mul	    $v0 $v0 $t1
    add	    $t0 $t0 $v0 # gradient = gradient + 2 * M(i-1, j)
    addi		$a2 $a2 1 # j+1
    jal		  lire_case

    add		  $t0 $t0 $v0 # gradient = gradient + M(i-1, j+1)
    addi		$a1 $a1 2 # i+1
    subu		$a2 $a2 2 # j-1
    jal		  lire_case

    subu		$t0 $t0 $v0 # gradient = gradient - M(i+1, j-1)
    addi		$a2 $a2 1 # j
    jal		  lire_case

    mul		  $v0 $v0 $t1
    subu		$t0 $t0 $v0 # gradient = gradient - 2 * M(i+1, j)
    addi		$a2 $a2 1 # j+1
    jal		  lire_case

    subu		$t0 $t0 $v0 # gradient = gradient - M(i+1, j+1)
    move		$v0 $t0 # $v0 = gradient
    move		$a1 $s1
  
  epilogue_calculerGradient:
    # Epilogue
    lw		  $s1 0($sp)
    lw		  $a2 4($sp)
    lw		  $ra 8($sp)
    lw		  $a1 12($sp)
    addi		$sp $sp 16
    jr	    $ra

#=============================================================================
# Calcule la matrice G (x ou y)
# Parametres: 
#   $a0: adresse de la matrice image
#   $a1: adresse de la matrice Gx ou Gy
#	  $a2: seuil inférieur
#	  $a3: 0 pour gradient horizontal, sinon gradient vertical
#=============================================================================
calculer_matrice:
  # Prologue
  subu		$sp $sp 44
  sw		  $a0 0($sp)
  sw		  $a1 4($sp)
  sw		  $a2 8($sp)
  sw		  $a3 12($sp)
  sw		  $s0 16($sp)
  sw		  $s1 20($sp)
  sw		  $s2 24($sp)
  sw		  $v0 28($sp)
  sw		  $ra 32($sp)
  sw		  $s3 36($sp)
  sw		  $s4 40($sp)

  # Corps
  move		$t6 $a2 # $t6 = seuil inférieur
  li		  $t7 255 # $t7 = seuil maximum 
  la		  $t0 entete_hauteur
  lw		  $s4 0($t0) # $s4 = hauteur de l'image
  la		  $t2 entete_largeur
  lw		  $s3 0($t2) # $s3 = hauteur de l'image
  subu		$t8 $s4 1 # $t8 = hauteur-1
  subu		$t9 $s3 1 # $t9 = largeur-1
  move		$s0 $a0 # $s0 adresse de la matrice M de l'image
  move		$s1 $a1 # $s1 = adresse de G (x ou y)
  move		$s2 $a3 # $s2 = X ou Y
  li		  $a1 0 

  boucle_i:
    beq		  $a1 $s4 finBoucle_i # si i = hauteur, on quitte la boucle
    li		  $a2 0 

  boucle_j: 
    beq		  $a2 $s3 finBoucle_j # si j = largeur, on quitte la boucle
    beqz		$a1 zero # si i = 0, on met a 0
    beqz		$a2 zero # si j = 0, on met a 0
    beq		  $a1 $t8 zero # si i = hauteur-1, on met a 0 
    beq		  $a2 $t9 zero # si j - largeur-1, on met a 0
    move		$a0 $s0 # $a0 = adresse de la matrice
    
    # On calcule le gradient
    beqz		$s2 calcul_gradient_x # si $s2 = 0, on calcule le gradient X
    li      $a3 1 # $a3 = 1 pour calculer gradient vertical
    jal		  calculer_gradient # sinon on calcule le gradient Y
    j		    fin_xy

  calcul_gradient_x:
    li      $a3 0 # $a3 = 0 pour calculer gradient horizontal
    jal		  calculer_gradient
    j		    fin_xy

  fin_xy:
    bltz    $v0 absolue # si $v0 est negatif, $v0 = valeur absolue de $v0

  verifier_valeur:
    bgt		  $v0 $t7 max # si $v0 est > a 255 on le met a 255
    blt		  $v0 $t6 zero # si $v0 est < au seuil on le met a 0
    move		$a3 $v0 # $a3 = gradient 
    j		    continuer_cgx # on continue

  absolue:
    negu    $v0 $v0
    j		    verifier_valeur # on verifie si $v0 est compris entre 0 et 255

  zero:
    li		  $a3 0         # on le met a 0
    j		    continuer_cgx 

  max:
    li		  $a3 255       # on le met a 255
    j		    continuer_cgx 

  continuer_cgx:
    move		$a0 $s1       # $a0 = adresse de Gx 
    jal	    modifier_case # $a3 = l'element ($a1,$a2)
    addi		$a2 $a2 1     # on incremente j
    j		    boucle_j      # on boucle sur j

  finBoucle_j:
    addi		$a1 $a1 1     # on incremente i
    j		    boucle_i      # on boucle sur i  

  finBoucle_i:
    # Epilogue
    lw		  $a0 0($sp)
    lw		  $a1 4($sp)
    lw		  $a2 8($sp)
    lw		  $a3 12($sp)
    lw		  $s0 16($sp)
    lw		  $s1 20($sp)
    lw		  $s2 24($sp)
    lw		  $v0 28($sp)
    lw		  $ra 32($sp)
    lw		  $s3 36($sp)
    lw		  $s4 40($sp)
    addi		$sp $sp 44
    jr	  	$ra

#=============================================================================
# Additionne deux matrices 
# Parametres: 
#   $a0: matrice Gx 
#   $a1: matrice Gy 
#   $a2: seuil inférieur
#=============================================================================
ajouter_deux_matrices:
  # Prologue
  subu		$sp $sp 16
  sw		  $ra 0($sp)
  sw		  $a0 4($sp)
  sw		  $a1 8($sp)
  sw		  $a2 12($sp)

  # Corps
  la	    $t9 entete_largeur
  lw	    $t7 0($t9)          # $t7 = largeur de la matrice
  la	    $t8 entete_hauteur 
  lw	    $t6 0($t8) 					# $t6 = hauteur de la matrice
  lw	    $t0 0($t8)
  li	    $t4 255 	# $t4 = seuil maximum
  move		$t5 $a2 	# $t5 = seuil inférieur

  boucle_ajoutMatriceI:
    beq		  $t0 $0 finBoucle_ajoutMatrice # on quitte la boucle si on a fais toutes les lignes
    lw		  $t1 0($t9) 										# on met la condition d'arret pour les colonnes
   
    boucle_ajoutMatriceJ:
      beq		  $t1 $0 finDeBoucle_j
      # On recupere l'element de la premiere matrice 
      lw		  $a0 4($sp)  # $a0 = adresse de la matrice 1 
      move		$a1 $t0     # $a1 = la ligne 
      move		$a2 $t1     # $a2 = la colonne
      jal		  lire_case
      move		$t3 $v0     # $t3 = resultat 

      # On recupere l'element de la	deuxieme matrice 
      lw		  $a0 8($sp)  # $a0 = adresse de la matrice 1 
      move		$a1 $t0     # $a1 = la ligne 
      move		$a2 $t1     # $a2 = la colonne
      jal		  lire_case
      
      # On additionne les deux cases
      add	    $v0 $v0 $t3 # $v0 = resultat de l'addition
      blt	    $v0 $t5 seuil_inferieur # on verifie que c'est > au seuil 
      bgt	    $v0 $t4 seuil_superieur # on verifie que c'est < a 255
      j		    continuer_ajouterMatrices

      seuil_inferieur:
        li		  $v0 0 # si $v0 < seuil on le met a 0 
        j		    continuer_ajouterMatrices

      seuil_superieur:
        li		  $v0 255 # si $v0 > 255 on le met a 255 

      continuer_ajouterMatrices:
        lw		  $a0 4($sp)	# $a0 = adresse de la premiere matrice
        move		$a1 $t0 		# $a1 = la ligne ou on veut modifier l'element
        move		$a2 $t1 		# $a2 = la colonne ou on veut modifier l'element
        move		$a3 $v0 		# $a3 = la somme des 2 cases
        jal		  modifier_case

        # On passe a la prochaine colonne
        subu		$t1 $t1 1 
        j		    boucle_ajoutMatriceJ

    finDeBoucle_j:
      # On passe a la prochaine ligne parce qu'on a fait toutes les colonnes de cette ligne
      subu		$t0 $t0 1 
      j		    boucle_ajoutMatriceI

  finBoucle_ajoutMatrice:
    # Epilogue
    lw		  $ra 0($sp)
    lw		  $a0 4($sp)
    lw		  $a1 8($sp)
    lw		  $a2 12($sp)
    addi		$sp $sp 16
    jr		  $ra





#=============================================================================
#
# Fonctions divers 
#
#=============================================================================

#=============================================================================
# Affiche une chaine de caracteres
# Parametres: 
#   $a0: adresse de la chaine a afficher
#=============================================================================
afficher_chaine:
  # Prologue
  subu		$sp $sp 8
  sw		  $ra 0($sp)
  sw		  $a0 4($sp)

  # Corps
  li		  $v0 4   # appel systeme 4 = afficher chaine
  syscall

  # Epilogue
  lw		  $ra 0($sp)
  lw		  $a0 4($sp)
  addiu   $sp $sp 8
  jr		  $ra

#=============================================================================
# Demande un nom de fichier
# Parametres: 
#   $a0: buffer pour la chaine de caracteres
#	  $a1: nombre max de caracteres a lire
# Retour: 
#   $v0: buffer rempli et traite
#=============================================================================
demander_nom_fichier:
  # Prologue
  subu		$sp $sp 20
  sw		  $ra 0($sp)
  sw		  $v0 4($sp)
  sw		  $a2 8($sp)
  sw		  $a3 12($sp)
  sw		  $s1 16($sp)

  # Corps
  li		  $a1 40            # $a1 = nombre de caracteres max
  li		  $v0 8             # appel systeme 8 = lire chaine
  syscall                   # $a0 = adresse du buffer
  move		$a3 $a0           # $a3 = adresse du buffer 
  la		  $a2 char_retour   # $a2 = adresse de la chaine "\n"
  lb		  $t9 0($a2)        # $t9 = "\n" sur 1 octet
  li		  $s1 0             # $s1 = compteur de caracteres

  boucle_nomFichier:
    beq		  $a1 $s1 finBoucle_nomFichier # on termine si le compteur de caracteres atteint le max ($a1)
    lb		  $t8 0($a3) # $t8 = la		lettre a l'adresse actuelle
    beq		  $t8 $t9 remplacer # si on detecte la chaine "\n" on passe au remplacement
    addi		$a3 $a3 1 # on se deplace dans la chaine au caractere suivant
    addi		$s1 $s1 1 # on incremente le compteur de caracteres
    j		    boucle_nomFichier # on boucle

  remplacer:
    la		  $a2 char_fin_chaine # $a2 = adresse de la chaine "\0"
    lb		  $t9 0($a2) # $t9 = "\0" sur 1 octet" 
    sb		  $t9 0($a3) # on remplace le "\n" par "\0"

  finBoucle_nomFichier:
    # Epilogue
    lw		  $ra 0($sp)
    lw		  $v0 4($sp)
    lw		  $a2 8($sp)
    lw		  $a3 12($sp)
    lw		  $s1 16($sp)
    addi		$sp $sp 20
    jr		  $ra

#=============================================================================
# Ouvre un fichier en mode lecture ou ecriture 
# Parametres:
#   $a0: chemin vers le fichier a ouvrir
#   $a1: flag pour le syscall (0 = mode lecture, 1 = mode ecriture)
# Retour:
#   $v0: descripteur de fichier
ouvrir_fichier:
  # Prologue
  subu		$sp $sp 12
  sw		  $ra 0($sp)
  sw		  $a0 4($sp)
  sw		  $a1 8($sp)

  # Corps
  li	  	$v0 13 # appel systeme 13 = ouvrir fichier
  syscall 

  blt		  $v0 0 erreur_ouvrirFichier # erreur si $v0 < 0
  j		    epilogue_ouvrirFichier

  erreur_ouvrirFichier:
    la		  $a0 texte_erreur_ouverture
    jal		  afficher_chaine
    jal		  quitter_programme

  epilogue_ouvrirFichier:
    # Epilogue
    lw		  $ra 0($sp)
    lw		  $a0 4($sp)
    lw		  $a1 8($sp)
    addi		$sp $sp 12
    jr	  	$ra

#=============================================================================
# Verifie que la signature du fichier = "BM" (format ".bmp")
# Parametres: 
#   $a0: descripteur de fichier
#   $a1: adresse du signature 
#=============================================================================
verifier_signature:  
  # Prologue
  subu	  $sp $sp 12
  sw		  $ra 0($sp)
  sw		  $a0 4($sp)
  sw		  $a1 8($sp)

  # Corps
  lb		  $t8 0($a1) # $t8 = 1ere lettre lue
  lb		  $t9 0($a2) # $t9 = lettre B
  bne		  $t8 $t9 erreur_verifierSignature # on verifie la premiere lettre
  lb		  $t8 1($a1) # $t8 = 2eme lettre lue
  lb		  $t9 1($a2) # $t9 = lettre M
  bne		  $t8 $t9 erreur_verifierSignature # on verifie la deuxieme lettre

  # Epilogue 
  lw		  $ra 0($sp)
  lw		  $a0 4($sp)
  lw		  $a1 8($sp)
  addi	  $sp $sp 12
  jr		  $ra
  
  # On quitte le programme si la signature du fichier est pas valide
  erreur_verifierSignature: 
    la		  $a0 texte_erreur_bmp
    jal		  afficher_chaine
    jal		  quitter_programme

#=============================================================================
# Quitte le programme
#=============================================================================
quitter_programme:
  li		  $v0 10 # appel systeme 10 = terminer l'execution du programme
  syscall
