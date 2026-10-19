const fs = require('fs')
const path = require('path')

const W = 595.28, H = 841.89
const C = {
  ink: '#14251C', muted: '#5D6B62', soft: '#F3F6F2', line: '#DCE5DC', white: '#FFFFFF',
  green: '#14834B', green2: '#E7F3EA', red: '#C92A35', red2: '#FCEBED', gold: '#E9B91B',
  dark: '#202722', mid: '#35443A', pale: '#FBFCFA', blue: '#315A72', blue2: '#E8F0F4',
}
const pages = []
let ops = []
const esc = s => String(s).replace(/\\/g,'\\\\').replace(/\(/g,'\\(').replace(/\)/g,'\\)')
const rgb = hex => [1,3,5].map(i => parseInt(hex.slice(i,i+2),16)/255)
const cp1252 = {
  '€':0x80,'‚':0x82,'ƒ':0x83,'„':0x84,'…':0x85,'†':0x86,'‡':0x87,'ˆ':0x88,'‰':0x89,'Š':0x8a,'‹':0x8b,'Œ':0x8c,'Ž':0x8e,
  '‘':0x91,'’':0x92,'“':0x93,'”':0x94,'•':0x95,'–':0x96,'—':0x97,'˜':0x98,'™':0x99,'š':0x9a,'›':0x9b,'œ':0x9c,'ž':0x9e,'Ÿ':0x9f,
}
function hexText(s) {
  const bytes = []
  for (const ch of String(s)) {
    const n = ch.codePointAt(0)
    if (n <= 255) bytes.push(n)
    else if (cp1252[ch] !== undefined) bytes.push(cp1252[ch])
    else bytes.push(0x3f)
  }
  return `<${bytes.map(b=>b.toString(16).padStart(2,'0')).join('')}>`
}
function emit(op) { ops.push(op) }
function rect(x,y,w,h,fill,stroke=null,r=0) { emit({k:'r',x,y,w,h,fill,stroke,r}) }
function line(x1,y1,x2,y2,color=C.line,width=1) { emit({k:'l',x1,y1,x2,y2,color,width}) }
function txt(x,y,s,size=10,color=C.ink,bold=false) { emit({k:'t',x,y,s:String(s),size,color,bold}) }
function approx(s,size) { let units=0; for(const ch of String(s)) units += 'il.,:;!|\' '.includes(ch)?0.28:'MW@#%'.includes(ch)?0.82:0.54; return units*size }
function wrap(s,maxWidth,size) {
  const words=String(s).split(/\s+/); let lines=[], current=''
  for(const word of words){ const next=current?`${current} ${word}`:word; if(current&&approx(next,size)>maxWidth){lines.push(current);current=word}else current=next }
  if(current)lines.push(current); return lines
}
function para(x,y,s,maxWidth,size=10,color=C.ink,leading=size*1.42,bold=false){let cy=y;for(const l of wrap(s,maxWidth,size)){txt(x,cy,l,size,color,bold);cy+=leading}return cy}
function pill(x,y,label,fill=C.green2,color=C.green){const w=approx(label,8)+18;rect(x,y-12,w,19,fill,null,8);txt(x+9,y,label,8,color,true);return w}
function sectionTag(label,y){rect(42,y-14,7,18,C.gold);txt(57,y,label.toUpperCase(),8,C.green,true)}
function pageHeader(kicker,title,subtitle,n){rect(0,0,W,H,C.white);rect(0,0,W,7,C.green);rect(0,7,95,4,C.red);rect(95,7,55,4,C.gold);txt(42,34,'SIGIA-AMINE  /  NOTICE D’UTILISATION',8,C.muted,true);txt(W-64,34,String(n).padStart(2,'0'),9,C.green,true);txt(42,66,kicker.toUpperCase(),8,C.green,true);txt(42,94,title,22,C.ink,true);para(42,115,subtitle,W-84,9.5,C.muted,13);line(42,133,W-42,133,C.line,0.8)}
function footer(n){line(42,H-36,W-42,H-36,C.line,.7);txt(42,H-25,'GUIDE OPÉRATIONNEL  •  AL AMINE',7,C.muted,true);txt(W-118,H-25,`OCTOBRE 2026  •  ${n}`,7,C.muted)}
function page(kicker,title,subtitle){pages.push({content:'',ops:[]});ops=pages.at(-1).ops;pageHeader(kicker,title,subtitle,pages.length)}
function callout(x,y,w,title,body,kind='green'){const color=kind==='red'?C.red:kind==='blue'?C.blue:C.green;const fill=kind==='red'?C.red2:kind==='blue'?C.blue2:C.green2;const bodyLines=wrap(body,w-32,8.7);const h=37+bodyLines.length*12;rect(x,y,w,h,fill,null,8);rect(x,y,4,h,color,null,2);txt(x+15,y+18,title,9,color,true);para(x+15,y+34,body,w-30,8.7,C.ink,12);return h}
function panel(x,y,w,h,title,tag='ÉCRAN DE L’APPLICATION'){rect(x,y,w,h,C.pale,C.line,9);rect(x,y,w,25,C.dark,null,8);rect(x,y+17,w,8,C.dark);rect(x+12,y+9,6,6,C.red,null,3);rect(x+23,y+9,6,6,C.gold,null,3);rect(x+34,y+9,6,6,C.green,null,3);txt(x+49,y+16,title,7.6,C.white,true);txt(x+w-115,y+16,tag,6.4,'#D5E0D8',true);return {x:x+12,y:y+38,w:w-24,h:h-50}}
function label(x,y,s){txt(x,y,s.toUpperCase(),6.8,C.muted,true)}
function input(x,y,w,s='',height=23){rect(x,y,w,height,C.white,C.line,4);if(s)txt(x+8,y+height/2+3,s,7.5,C.muted)}
function button(x,y,w,s,fill=C.green){rect(x,y,w,22,fill,null,5);txt(x+10,y+14,s,7.4,C.white,true)}
function screenNav(x,y,w){rect(x,y,104,180,C.dark);rect(x+12,y+12,17,17,C.green,null,5);txt(x+36,y+20,'SIGIA-AMINE',7.5,C.white,true);txt(x+12,y+44,'Complexe scolaire',6,'#B8C5BB');let labels=['Tableau de bord','Administration','Pédagogie','Vie scolaire','Finance'];let yy=y+70;for(const s of labels){if(s==='Administration'||s==='Pédagogie'||s==='Finance')rect(x+8,yy-11,w-16,19,C.mid,null,4);txt(x+15,yy,s,7,'#E6ECE7');yy+=24}return x+116}
function miniRow(x,y,w,cols){rect(x,y,w,19,'#EDF2ED',null,3);let cx=x+7;for(const [s,cw] of cols){txt(cx,y+13,s,6,C.muted,true);cx+=cw}}
function captureLogin(x,y,w,h){const p=panel(x,y,w,h,'Connexion /login');rect(p.x,p.y,p.w,p.h,'#F5F7F4',null,3);rect(p.x+20,p.y+20,p.w-40,26,C.dark,null,4);txt(p.x+30,p.y+37,'Portail de gestion scolaire',7,C.white,true);const bx=p.x+p.w/2-80;rect(bx,p.y+45,160,29,C.green2,null,4);txt(bx+13,p.y+64,'SIGIA  AMINE',11,C.green,true);txt(bx-18,p.y+88,'Gestion des établissements scolaires',7.2,C.ink,true);const fx=p.x+p.w/2-83;rect(fx,p.y+94,166,Math.min(118,p.h-118),C.white,C.line,6);txt(fx+13,p.y+109,'Connexion',8,C.green,true);label(fx+13,p.y+128,'Adresse e-mail');input(fx+13,p.y+132,140,'nom@exemple.com',17);label(fx+13,p.y+158,'Mot de passe');input(fx+13,p.y+162,140,'••••••••',17);button(fx+13,p.y+184,140,'Se connecter');rect(p.x,p.y+p.h-20,p.w,20,C.dark);txt(p.x+9,p.y+p.h-6,'Maternelle  •  Primaire  •  Secondaire  •  Centre de formation  •  Parent',6.2,C.white,true)}
function captureDashboard(x,y,w,h){const p=panel(x,y,w,h,'Tableau de bord /dashboard');const mx=screenNav(p.x,p.y,p.w);const cw=p.x+p.w-mx-8;txt(mx,p.y+11,'Tableau de bord',10,C.ink,true);txt(mx,p.y+24,'Bienvenue dans votre espace de travail.',6.6,C.muted);let ww=(cw-21)/3;[['ÉLÈVES','248'],['CLASSES ACTIVES','16'],['ANNÉE SCOLAIRE','2026-2027']].forEach((a,i)=>{let xx=mx+i*(ww+8);rect(xx,p.y+34,ww,46,C.white,C.line,5);txt(xx+8,p.y+48,a[0],5.8,C.muted,true);txt(xx+8,p.y+69,a[1],12,C.green,true)});rect(mx,p.y+91,cw,Math.max(38,p.h-105),C.white,C.line,5);txt(mx+9,p.y+106,'Accès rapides',7,C.ink,true);txt(mx+10,p.y+125,'Ouvrir les élèves',6.6,C.green,true);txt(mx+120,p.y+125,'Administration',6.6,C.green,true)}
function captureStudent(x,y,w,h){const p=panel(x,y,w,h,'Nouveau dossier élève /administration/eleves/nouveau');const mx=screenNav(p.x,p.y,p.w);let cw=p.x+p.w-mx-8;txt(mx,p.y+11,'Nouveau dossier élève',9,C.ink,true);txt(mx,p.y+23,'Étape 1 : dossier administratif de base.',6,C.muted);rect(mx,p.y+32,cw,p.h-40,C.white,C.line,5);let xx=mx+9, yy=p.y+49, iw=(cw-27)/2;[['MATRICULE *','ELV-0001'],['GENRE','Sélectionner'],['PRÉNOM *','Aïcha'],['NOM *','Traoré'],['DATE DE NAISSANCE','JJ/MM/AAAA'],['RÉGIME','Externe']].forEach((a,i)=>{let col=i%2,row=Math.floor(i/2),ax=xx+col*(iw+9),ay=yy+row*44;label(ax,ay,a[0]);input(ax,ay+4,iw,a[1],21)});button(xx,yy+139,102,'Enregistrer l’élève')}
function capturePedagogy(x,y,w,h){const p=panel(x,y,w,h,'Évaluations /pedagogie/evaluations');const mx=screenNav(p.x,p.y,p.w);let cw=p.x+p.w-mx-8;txt(mx,p.y+11,'Évaluations',9,C.ink,true);txt(mx,p.y+23,'Notes et publication',6,C.muted);button(mx+cw-96,p.y+4,92,'Nouvelle évaluation');rect(mx,p.y+34,cw,p.h-42,C.white,C.line,5);miniRow(mx+7,p.y+44,cw-14,[['ÉVALUATION',80],['CLASSE',80],['PÉRIODE',72],['STATUT',54]]);[['Devoir 1','6e A','Trimestre 1','Brouillon'],['Composition','6e A','Trimestre 1','Publié'],['Interrogation','5e B','Trimestre 1','Brouillon']].forEach((r,i)=>{const yy=p.y+70+i*25;txt(mx+13,yy,r[0],6.5,C.ink);txt(mx+93,yy,r[1],6.5,C.ink);txt(mx+173,yy,r[2],6.5,C.ink);pill(mx+246,yy-2,r[3],r[3]==='Publié'?C.green2:C.blue2,r[3]==='Publié'?C.green:C.blue)})}
function captureAttendance(x,y,w,h){const p=panel(x,y,w,h,'Nouvelle séance d’appel /vie-scolaire/presences/nouveau');const mx=screenNav(p.x,p.y,p.w);let cw=p.x+p.w-mx-8;txt(mx,p.y+11,'Nouvelle séance d’appel',9,C.ink,true);txt(mx,p.y+23,'Sélectionner année et classe avant la saisie.',6,C.muted);rect(mx,p.y+33,cw,p.h-41,C.white,C.line,5);let iw=(cw-27)/2;[['ANNÉE SCOLAIRE','2026-2027'],['CLASSE','6e A'],['DATE','17/10/2026'],['ACTIVITÉ','Cours'],['HEURE DÉBUT','08:00'],['HEURE FIN','10:00']].forEach((a,i)=>{let ax=mx+9+(i%2)*(iw+9),ay=p.y+48+Math.floor(i/2)*41;label(ax,ay,a[0]);input(ax,ay+4,iw,a[1],20)});button(mx+9,p.y+179,98,'Créer la séance')}
function captureFinance(x,y,w,h){const p=panel(x,y,w,h,'Tarification /finance/tarifs');const mx=screenNav(p.x,p.y,p.w);let cw=p.x+p.w-mx-8;txt(mx,p.y+10,'Tarification',9,C.ink,true);txt(mx,p.y+22,'Types de frais et référentiel financier.',5.9,C.muted);rect(mx,p.y+30,cw,105,C.white,C.line,5);txt(mx+8,p.y+43,'Nouveau type de frais',7.2,C.ink,true);let iw=(cw-30)/2;[['CODE','SCOLARITE'],['NOM','Frais de scolarité'],['CATÉGORIE','scolarite'],['PRIX (FCFA)','500 000']].forEach((a,i)=>{let ax=mx+8+(i%2)*(iw+10),ay=p.y+54+Math.floor(i/2)*31;label(ax,ay,a[0]);input(ax,ay+3,iw,a[1],17)});button(mx+8,p.y+116,50,'Créer');rect(mx,p.y+143,cw,Math.max(38,p.h-151),C.white,C.line,5);txt(mx+8,p.y+157,'Types de frais',7,C.ink,true);miniRow(mx+7,p.y+163,cw-14,[['CODE',50],['NOM',93],['CATÉGORIE',66],['PRIX',50]])}
function captureAccess(x,y,w,h){const p=panel(x,y,w,h,'Accès utilisateurs /administration-it/acces');const mx=screenNav(p.x,p.y,p.w);let cw=p.x+p.w-mx-8;txt(mx,p.y+10,'Accès utilisateurs',9,C.ink,true);txt(mx,p.y+22,'Rôles, connexion et pages accessibles',5.8,C.muted);let left=Math.max(75,cw*.34),right=cw-left-7;rect(mx,p.y+31,left,p.h-38,C.white,C.line,5);txt(mx+8,p.y+44,'Utilisateurs',7,C.ink,true);['Aïcha Traoré','Moussa Diallo','Fatou Sawadogo'].forEach((s,i)=>{const yy=p.y+57+i*26;rect(mx+5,yy-10,left-10,21,i===0?C.green2:C.pale,C.line,4);txt(mx+11,yy+3,s,6.3,C.ink,i===0)});const rx=mx+left+7;rect(rx,p.y+31,right,p.h-38,C.white,C.line,5);txt(rx+9,p.y+45,'Aïcha Traoré',7,C.ink,true);label(rx+9,p.y+61,'ACCÈS À LA CONNEXION');input(rx+9,p.y+65,right-18,'Autorisé',18);button(rx+9,p.y+88,right-18,'Enregistrer l’accès');txt(rx+9,p.y+122,'Rôles et privilèges',7,C.ink,true);input(rx+9,p.y+128,right-18,'Ajouter ou réactiver un rôle',18);button(rx+9,p.y+151,right-18,'Attribuer le rôle')}
function screenshotNote(x,y,s){txt(x,y,'CAPTURE ILLUSTRATIVE — noms et données d’exemple',6.7,C.muted,false)}

// Couverture
ops=[];rect(0,0,W,H,C.pale);rect(0,0,W,14,C.green);rect(0,14,192,7,C.red);rect(192,14,65,7,C.gold);txt(44,70,'SIGIA-AMINE  /  AL AMINE',9,C.green,true);txt(44,131,'NOTICE',34,C.ink,true);txt(44,174,'D’UTILISATION',34,C.ink,true);rect(44,194,78,4,C.gold);para(44,227,'Guide pratique pour se connecter, parcourir les modules et enregistrer les opérations courantes.',445,14,C.muted,21);rect(44,282,507,319,C.white,C.line,13);captureLogin(58,300,479,235);txt(72,565,'Accès illustratif : aucune donnée personnelle réelle n’est affichée.',8,C.muted);rect(44,637,507,76,C.green,null,10);txt(64,666,'DU PREMIER PARAMÉTRAGE AUX OPÉRATIONS QUOTIDIENNES',9,C.white,true);para(64,685,'Administration • Pédagogie • Vie scolaire • Finance • Documents',465,9,C.white,13);txt(44,758,'Version 1.0  •  17 octobre 2026',9,C.muted,true);txt(44,790,'Illustrations de l’interface et exemples fictifs',8,C.muted);pages.push({content:'',ops});

// Page 2
page('01  •  Démarrer','Se connecter et s’orienter','L’accès dépend du compte actif et des autorisations associées à votre rôle.')
captureLogin(42,149,511,286);screenshotNote(54,447,'Capture illustrative — champs vides, aucune identité réelle.')
sectionTag('Connexion',482);let cy=502
cy=para(57,cy,'1. Ouvrir l’adresse du portail SIGIA-AMINE fournie par votre établissement.',490,9.2,C.ink,13)+7
cy=para(57,cy,'2. Choisir votre espace en bas de l’écran : Maternelle, Primaire, Secondaire, Centre de formation ou Parent.',490,9.2,C.ink,13)+7
cy=para(57,cy,'3. Saisir votre adresse e-mail et votre mot de passe, puis cliquer sur « Se connecter ».',490,9.2,C.ink,13)+7
cy=para(57,cy,'4. Dans le menu latéral, ouvrir un module. Le tableau de bord donne les raccourcis et quelques indicateurs.',490,9.2,C.ink,13)+12
callout(42,cy,511,'Enregistrer une saisie','Remplir les champs obligatoires marqués *, cliquer sur le bouton de validation du formulaire, attendre le message de confirmation, puis vérifier que l’élément apparaît dans la liste. Les formulaires ne se sauvegardent pas automatiquement.','green')
footer(2)

// Page 3
page('02  •  Paramétrage','Préparer l’année, les niveaux et les classes','Ces référentiels alimentent les inscriptions, les matières, les affectations et les appels.')
let p=panel(42,148,511,242,'Classes /administration/classes/nouveau');let mx=screenNav(p.x,p.y,p.w);let cw=p.x+p.w-mx-8;txt(mx,p.y+12,'Nouvelle classe',10,C.ink,true);txt(mx,p.y+25,'Rattacher la classe à la bonne année scolaire.',6.5,C.muted);rect(mx,p.y+36,cw,p.h-45,C.white,C.line,5);[['ANNÉE SCOLAIRE *','2026-2027'],['NIVEAU *','Sixième'],['NOM *','6e A'],['CODE *','6A-2026'],['SALLE','Salle 4'],['CAPACITÉ','40']].forEach((a,i)=>{let iw=(cw-27)/2,ax=mx+9+(i%2)*(iw+9),ay=p.y+51+Math.floor(i/2)*37;label(ax,ay,a[0]);input(ax,ay+4,iw,a[1],19)});button(mx+9,p.y+166,94,'Créer la classe');screenshotNote(54,402,'Exemple de formulaire ; données fictives.')
sectionTag('Ordre de préparation recommandé',433);let yy=454
;[['1','Année scolaire','Créer l’année et définir celle qui sert de référence aux opérations.'],['2','Niveaux','Créer les niveaux utilisés par l’établissement.'],['3','Classes','Rattacher chaque classe à son niveau et à l’année concernée.']].forEach(([n,t,b])=>{pill(44,yy+7,n,C.green2,C.green);txt(75,yy+7,t,9,C.ink,true);yy=para(75,yy+22,b,448,8.4,C.muted,12)+9})
callout(42,yy+1,511,'Avant de finaliser une inscription','Vérifier que l’année, le niveau et la classe choisis correspondent bien. Certaines opérations sont refusées si ces référentiels ne sont pas cohérents.', 'blue')
footer(3)

// Page 4
page('03  •  Administration','Admissions, élèves et familles','Une préinscription examinée et approuvée précède l’inscription définitive.')
captureStudent(42,148,511,247);screenshotNote(54,407,'Capture illustrative — valeurs entièrement fictives.')
sectionTag('Parcours d’une nouvelle famille',439);yy=461
;[['Admission','Créer une préinscription, choisir l’année et le niveau souhaités, puis enregistrer. Elle est initialement en attente.'],['Décision','Ouvrir le dossier de candidature, vérifier les informations et approuver, rejeter ou annuler.'],['Élève','Après approbation, créer ou rattacher le dossier élève et compléter son identité.'],['Inscription','Créer l’inscription pour l’année, sélectionner la classe lorsque le référentiel est prêt, puis finaliser.'],['Parent','Créer ou sélectionner le parent/tuteur, puis le lier au dossier de l’élève.']].forEach(([t,b],i)=>{txt(45,yy,`${i+1}.`,9,C.green,true);txt(65,yy,t,9,C.ink,true);yy=para(65,yy+14,b,480,8.4,C.muted,12)+7})
callout(42,yy,511,'Pour sauvegarder le dossier élève','Compléter au minimum le matricule, le prénom et le nom. Cliquer sur « Enregistrer l’élève ». À la confirmation, ouvrir la liste des élèves et rechercher le matricule.', 'green')
footer(4)

// Page 5
page('04  •  Pédagogie','Préparer les cours, saisir les notes','Respecter l’enchaînement matière > affectation > évaluation > notes > bulletin.')
capturePedagogy(42,148,511,254);screenshotNote(54,414,'Capture illustrative — noms et résultats d’exemple.')
sectionTag('Procédure pédagogique',445);yy=468
;[['Référentiels','Créer les matières, vérifier les niveaux/classes et les périodes scolaires.'],['Affectation','Associer un enseignant actif à une classe et à une matière pour la bonne année.'],['Évaluation','Créer un type si nécessaire, puis l’évaluation liée à l’affectation et à la période.'],['Notes','Ouvrir l’évaluation, saisir les notes des élèves concernés et enregistrer. Contrôler les valeurs avant publication.'],['Bulletin','Générer un brouillon à partir des notes publiées, vérifier le contenu puis publier si vous y êtes autorisé.']].forEach(([t,b],i)=>{txt(45,yy,`${i+1}.`,9,C.green,true);txt(65,yy,t,9,C.ink,true);yy=para(65,yy+14,b,480,8.4,C.muted,12)+7})
callout(42,yy,511,'Attention à la publication','La publication verrouille certaines modifications. Vérifier la classe, la période, les notes et les moyennes avant de publier.', 'red')
footer(5)

// Page 6
page('05  •  Vie scolaire','Enregistrer les présences et le suivi','Les séances d’appel sont rattachées à une année, une classe et une date.')
captureAttendance(42,148,511,254);screenshotNote(54,414,'Capture illustrative — classe et horaires d’exemple.')
sectionTag('Créer puis compléter un appel',445);yy=469
yy=para(46,yy,'1. Dans « Vie scolaire », ouvrir « Présences et appels », puis choisir « Nouvelle séance ».',500,8.9,C.ink,13)+8
yy=para(46,yy,'2. Sélectionner l’année scolaire et la classe ; renseigner la date et l’activité. Matière, responsable et horaires peuvent être complétés si nécessaire.',500,8.9,C.ink,13)+8
yy=para(46,yy,'3. Cliquer sur « Créer la séance ». Ouvrir la séance créée pour saisir le statut de chaque élève.',500,8.9,C.ink,13)+8
yy=para(46,yy,'4. Enregistrer les présents, absents, retards ou absences justifiées, puis vérifier le récapitulatif.',500,8.9,C.ink,13)+10
callout(42,yy,511,'Autres suivis','Les menus « Justificatifs », « Discipline », « Suivi éducatif » et « Récompenses » conservent leurs informations dans le dossier de l’élève, selon les permissions de votre compte.','blue')
footer(6)

// Page 7
page('06  •  Finance','Tarifs, factures et paiements','Le solde restant correspond au montant dû diminué des paiements affectés.')
captureFinance(42,148,511,256);screenshotNote(54,418,'Capture illustrative — montants fictifs ; devise FCFA.')
sectionTag('Créer un type de frais',449);yy=472
yy=para(46,yy,'1. Ouvrir « Finance > Tarifs ». Renseigner un code, un nom, une catégorie et le prix en FCFA ; la description est facultative.',500,8.8,C.ink,13)+7
yy=para(46,yy,'2. Cliquer sur « Créer », attendre la confirmation, puis vérifier le prix dans le tableau des types de frais.',500,8.8,C.ink,13)+7
yy=para(46,yy,'3. Créer les échéanciers ou la facture de l’élève concerné en sélectionnant l’année et les frais appropriés.',500,8.8,C.ink,13)+7
yy=para(46,yy,'4. Pour encaisser, ouvrir « Paiements > Nouveau paiement », sélectionner l’élève et la facture, saisir le montant, la date et le mode, puis enregistrer.',500,8.8,C.ink,13)+10
callout(42,yy,511,'Après l’encaissement','Vérifier le paiement et le reçu dans la liste. Consulter « Impayés » pour le reste à payer ; ne pas remplacer le total dû par le solde restant.', 'green')
footer(7)

// Page 8
page('07  •  Autres modules','Poursuivre les opérations quotidiennes','Le menu latéral regroupe les autres fonctions disponibles selon les droits attribués.')
let p8=panel(42,148,511,230,'Modules / menu latéral');let mn=screenNav(p8.x,p8.y,p8.w);let cw8=p8.x+p8.w-mn-8;txt(mn,p8.y+12,'Espaces de travail',10,C.ink,true);txt(mn,p8.y+27,'Ouvrir le module adapté à votre tâche.',6.5,C.muted);[['Personnel et RH','Employés, enseignants, contrats, congés et paie.'],['Internat / restauration','Structures, affectations, repas et présences.'],['Stocks et achats','Produits, inventaires, mouvements, commandes et fournisseurs.'],['Documents / communication','Demandes, archives, annonces et notifications.'],['Statistiques / activités','Tableaux de bord, rapports, agriculture, élevage et activités.']].forEach((a,i)=>{let col=i%2,row=Math.floor(i/2),xx=mn+col*(cw8/2+4),yy0=p8.y+42+row*56;let ww=cw8/2-6;rect(xx,yy0,ww,48,C.white,C.line,5);txt(xx+8,yy0+15,a[0],6.8,C.green,true);para(xx+8,yy0+28,a[1],ww-16,5.7,C.muted,7.5)});screenshotNote(54,391,'Capture illustrative — menu simplifié.')
sectionTag('Règle commune pour les formulaires',421);yy=444
;[['Préparer','Vérifier que la fiche parent (élève, classe, employé, fournisseur…) existe.'],['Saisir','Renseigner les champs marqués *, contrôler dates, montants et liens sélectionnés.'],['Valider','Cliquer une seule fois sur le bouton d’action et patienter jusqu’au message de réussite.'],['Contrôler','Revenir à la liste, rechercher l’élément créé et vérifier ses informations.']].forEach(([t,b],i)=>{txt(45,yy,`${i+1}.`,9,C.green,true);txt(65,yy+14,t,9,C.ink,true);yy=para(65,yy+28,b,480,8.4,C.muted,12)+3})
callout(42,yy,511,'En cas de message d’erreur','Lire le message affiché, vérifier les champs obligatoires et le contexte (année, classe, établissement), puis corriger avant de soumettre de nouveau.', 'red')
footer(8)

// Page 9
page('08  •  Administration technique','Gérer les comptes et leurs accès','Ces pages sont réservées aux responsables habilités ; les choix de rôle ouvrent des permissions précises.')
captureAccess(42,148,511,257);screenshotNote(54,417,'Capture illustrative — noms et rôles d’exemple.')
sectionTag('Attribuer un rôle à un utilisateur',449);yy=472
yy=para(46,yy,'1. Ouvrir « Administration technique > Utilisateurs ». Cette liste affiche les comptes déjà créés pour l’établissement.',500,8.8,C.ink,13)+6
yy=para(46,yy,'2. Cliquer sur « Gérer » à côté du compte, ou ouvrir « Accès utilisateurs » et sélectionner la personne dans la liste.',500,8.8,C.ink,13)+6
yy=para(46,yy,'3. Dans « Rôles et privilèges », choisir un rôle puis cliquer « Attribuer le rôle ». Les pages accessibles dépendent des permissions de ce rôle.',500,8.8,C.ink,13)+6
yy=para(46,yy,'4. Pour autoriser ou suspendre la connexion, sélectionner l’état voulu dans « Accès à la connexion », puis cliquer « Enregistrer l’accès ». Vérifier la confirmation.',500,8.8,C.ink,13)+8
callout(42,yy,511,'Comptes existants','La page Utilisateurs sert à consulter et gérer les comptes déjà créés ; elle ne comporte pas de formulaire de création de compte. La création du compte de connexion doit être organisée par l’administrateur technique.','blue')
footer(9)

// assemblage PDF depuis les commandes vectorielles, police Helvetica WinAnsi
function pdfColor(hex){const [r,g,b]=rgb(hex);return `${r.toFixed(3)} ${g.toFixed(3)} ${b.toFixed(3)}`}
function pdfOps(list){let out=[];for(const o of list){if(o.k==='r'){const y=H-o.y-o.h;const f=pdfColor(o.fill);const s=o.stroke?pdfColor(o.stroke):null; if(o.r){const r=Math.min(o.r,o.w/2,o.h/2),k=.55228475, x=o.x; const p=[`${(x+r).toFixed(2)} ${y.toFixed(2)} m`,`${(x+o.w-r).toFixed(2)} ${y.toFixed(2)} l`,`${(x+o.w-r+r*k).toFixed(2)} ${y.toFixed(2)} ${(x+o.w).toFixed(2)} ${(y+r-r*k).toFixed(2)} ${(x+o.w).toFixed(2)} ${(y+r).toFixed(2)} c`,`${(x+o.w).toFixed(2)} ${(y+o.h-r).toFixed(2)} l`,`${(x+o.w).toFixed(2)} ${(y+o.h-r+r*k).toFixed(2)} ${(x+o.w-r+r*k).toFixed(2)} ${(y+o.h).toFixed(2)} ${(x+o.w-r).toFixed(2)} ${(y+o.h).toFixed(2)} c`,`${(x+r).toFixed(2)} ${(y+o.h).toFixed(2)} l`,`${(x+r-r*k).toFixed(2)} ${(y+o.h).toFixed(2)} ${x.toFixed(2)} ${(y+o.h-r+r*k).toFixed(2)} ${x.toFixed(2)} ${(y+o.h-r).toFixed(2)} c`,`${x.toFixed(2)} ${(y+r).toFixed(2)} l`,`${x.toFixed(2)} ${(y+r-r*k).toFixed(2)} ${(x+r-r*k).toFixed(2)} ${y.toFixed(2)} ${(x+r).toFixed(2)} ${y.toFixed(2)} c`].join('\n');out.push(`${f} rg ${s?`${s} RG 0.6 w`:''}\n${p}\n${o.stroke?'B':'f'}`)}else out.push(`${f} rg ${s?`${s} RG 0.6 w`:''}\n${o.x} ${y} ${o.w} ${o.h} re ${o.stroke?'B':'f'}`)}else if(o.k==='l'){out.push(`${pdfColor(o.color)} RG ${o.width} w ${o.x1} ${H-o.y1} m ${o.x2} ${H-o.y2} l S`)}else if(o.k==='t'){const font=o.bold?'F2':'F1';const y=H-o.y-o.size*0.82;out.push(`BT /${font} ${o.size} Tf ${pdfColor(o.color)} rg 1 0 0 1 ${o.x.toFixed(2)} ${y.toFixed(2)} Tm ${hexText(o.s)} Tj ET`)}}return out.join('\n')}
const objects=[]
const add=s=>{objects.push(s);return objects.length}
const catalogId=add('')
const pagesId=add('')
const f1=add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>')
const f2=add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>')
const pageIds=[]
for(const p of pages){const stream=pdfOps(p.ops);const streamId=add(`<< /Length ${Buffer.byteLength(stream,'binary')} >>\nstream\n${stream}\nendstream`);const pageId=add(`<< /Type /Page /Parent ${pagesId} 0 R /MediaBox [0 0 ${W} ${H}] /Resources << /Font << /F1 ${f1} 0 R /F2 ${f2} 0 R >> >> /Contents ${streamId} 0 R >>`);pageIds.push(pageId)}
objects[catalogId-1]=`<< /Type /Catalog /Pages ${pagesId} 0 R >>`
objects[pagesId-1]=`<< /Type /Pages /Count ${pageIds.length} /Kids [${pageIds.map(i=>`${i} 0 R`).join(' ')}] >>`
let pdf='%PDF-1.4\n%âãÏÓ\n', offsets=[0]
objects.forEach((o,i)=>{offsets.push(Buffer.byteLength(pdf,'binary'));pdf+=`${i+1} 0 obj\n${o}\nendobj\n`})
const xref=Buffer.byteLength(pdf,'binary');pdf+=`xref\n0 ${objects.length+1}\n0000000000 65535 f \n`;for(let i=1;i<offsets.length;i++)pdf+=`${String(offsets[i]).padStart(10,'0')} 00000 n \n`;pdf+=`trailer\n<< /Size ${objects.length+1} /Root ${catalogId} 0 R /Info << /Title ${hexText('Notice d’utilisation SIGIA-AMINE')} /Author ${hexText('Complexe Scolaire Al Amine')} /Subject ${hexText('Guide pratique illustré')} >> >>\nstartxref\n${xref}\n%%EOF\n`
const dest=path.resolve('output/pdf/notice_utilisation_sigia_amine.pdf')
fs.writeFileSync(dest,Buffer.from(pdf,'binary'))
fs.writeFileSync(path.resolve('tmp/pdfs/manual-ops.json'),JSON.stringify(pages.map(p=>p.ops)))
console.log(JSON.stringify({dest,pages:pages.length,bytes:Buffer.byteLength(pdf,'binary')}))
