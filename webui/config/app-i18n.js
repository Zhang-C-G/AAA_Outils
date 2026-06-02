const SUPPORTED_LANGS = new Set(['fr', 'zh']);

let currentLang = 'fr';
let observer = null;

const EXACT_FR = new Map(Object.entries({
  'Raccourci Control Web UI': 'Interface Web Raccourci Control',
  'Raccourci Control': 'Raccourci Control',
  'Web UI Config · 黑白风 · 阴影 · 动效': 'Configuration Web · style monochrome · ombres · animations',
  '已修改，系统将自动保存': 'Modifié, enregistrement automatique en cours',
  '设置': 'Réglages',
  '语言': 'Langue',
  '法语': 'Français',
  '中文': '中文',
  'A快捷字段': 'A Champs rapides',
  'B笔记': 'B Notes',
  'C笔记显示': 'C Affichage des notes',
  'D截图发手机': 'D Capture vers téléphone',
  'E截图问答': 'E Questions par capture',
  'F简历自动填写': 'F Remplissage auto du CV',
  'G快捷键': 'G Raccourcis',
  'H测试': 'H Tests',
  'I API管理中心': 'I Centre API',
  '新增栏目': 'Ajouter une rubrique',
  '触发词': 'Déclencheur',
  '内容': 'Contenu',
  '使用': 'Utilisation',
  '操作': 'Actions',
  '备份字段': 'Sauvegarder les champs',
  '从最近备份恢复': 'Restaurer la dernière sauvegarde',
  '导出为': 'Exporter en',
  '导出字段': 'Exporter les champs',
  '新增条目': 'Ajouter une entrée',
  '删除当前栏目': 'Supprimer la rubrique actuelle',
  '快捷键': 'Raccourcis',
  '恢复默认快捷键': 'Rétablir les raccourcis par défaut',
  '收起列表': 'Réduire la liste',
  '展开列表': 'Développer la liste',
  '删除笔记': 'Supprimer la note',
  '删除内容': 'Supprimer le contenu',
  '从': 'De',
  '到': 'À',
  '执行提取': 'Lancer l’extraction',
  '恢复正文': 'Restaurer le texte',
  '隐藏提取': 'Masquer l’extraction',
  '显示提取': 'Afficher l’extraction',
  '这里只填中间内容，系统会自动按 `**内容**` 的 Markdown 标记去识别；结果会直接进入主内容框集中显示并允许修改。': 'Saisissez seulement le contenu intermédiaire. Le système détecte automatiquement les marqueurs Markdown `**contenu**`, puis regroupe le résultat dans la zone principale pour modification.',
  '结构目录': 'Plan',
  '复制目录': 'Copier le plan',
  '把一大段 Markdown 贴进右侧后，这里会自动列出目录结构。': 'Collez un long texte Markdown à droite et le plan sera généré ici automatiquement.',
  '正文保存状态': 'État d’enregistrement du contenu',
  '正文内容字数': 'Nombre de caractères',
  '搜索': 'Rechercher',
  '搜索正文内容': 'Rechercher dans le contenu',
  '保存': 'Enregistrer',
  '保存快捷键': 'Enregistrer les raccourcis',
  '保存笔记': 'Enregistrer la note',
  '保存笔记显示内容': 'Enregistrer le contenu affiché',
  '保存截图设置': 'Enregistrer les réglages de capture',
  '保存助手设置': 'Enregistrer les réglages de l’assistant',
  '简历自动保存': 'Enregistrement auto du CV',
  '刷新 API 信息': 'Actualiser les infos API',
  '执行测试': 'Exécuter le test',
  '当前笔记导出格式': 'Format d’export de la note actuelle',
  '导出当前笔记': 'Exporter la note actuelle',
  '正文视图切换': 'Basculer la vue du contenu',
  'Markdown': 'Markdown',
  '最终版本': 'Version finale',
  '正文部分': 'Contenu principal',
  '笔记显示正文视图切换': 'Basculer la vue du contenu affiché',
  'Bridge Port': 'Port du pont',
  'Upload URL': 'URL d’envoi',
  '上传后自动打开二维码': 'Ouvrir le QR code après l’envoi',
  'PC: DISCONNECTED': 'PC : DÉCONNECTÉ',
  'PHONE: WAITING': 'TÉLÉPHONE : EN ATTENTE',
  '保存设置': 'Enregistrer les réglages',
  'Start Link': 'Démarrer la connexion',
  'Stop Link': 'Arrêter la connexion',
  'Capture Screen': 'Capturer l’écran',
  'Upload To Phone': 'Envoyer au téléphone',
  'Open Phone': 'Ouvrir sur le téléphone',
  'Open Folder': 'Ouvrir le dossier',
  'Latest Capture': 'Dernière capture',
  'Phone URL': 'URL téléphone',
  '基础设置': 'Réglages de base',
  '高级设置已关闭': 'Réglages avancés désactivés',
  '高级设置已开启': 'Réglages avancés activés',
  '模板选择': 'Choix du modèle',
  '模板名称': 'Nom du modèle',
  '新增模板': 'Nouveau modèle',
  '删除模板': 'Supprimer le modèle',
  '个人基本信息': 'Profil personnel',
  '例如：工作方向、年限、擅长技术、目标岗位、回答偏好。模型会先读取这段背景，再读取 Prompt。': 'Ex. : orientation métier, années d’expérience, technologies maîtrisées, poste visé, style de réponse. Le modèle lit d’abord ce contexte puis le prompt.',
  '高级设置': 'Réglages avancés',
  '通用': 'Général',
  '控制悬浮窗展示和通用调用策略。': 'Contrôle l’affichage de la fenêtre flottante et la stratégie générale d’appel.',
  '透明度档位': 'Niveau d’opacité',
  '悬浮球主色': 'Couleur principale de la bulle',
  '禁止复制悬浮窗答案': 'Interdire la copie des réponses flottantes',
  '启用每小时限流': 'Activer la limitation horaire',
  '每小时最多调用次数': 'Nombre max. d’appels par heure',
  '截图笔试': 'Capture d’écran',
  '管理截图问答链路的模型、保护模式和保存目录。': 'Gère le modèle, le mode protégé et le dossier d’enregistrement pour la chaîne de capture.',
  '问答模型选择': 'Modèle de questions-réponses',
  '增强模式：截图时本地可见，截图不可见，录屏不可见': 'Mode renforcé : visible localement, invisible dans les captures et les enregistrements',
  '截图保存目录': 'Dossier des captures',
  '打开目录': 'Ouvrir le dossier',
  '修改目录': 'Modifier le dossier',
  '语音面试': 'Entretien vocal',
  '管理 F3 语音识别、自动分析和上下文记忆。': 'Gère la reconnaissance vocale F3, l’analyse automatique et la mémoire de contexte.',
  '语音模型选择': 'Modèle vocal',
  '开启语音识别功能': 'Activer la reconnaissance vocale',
  '语音模型激活': 'Activer le modèle vocal',
  '麦克风选择': 'Choix du microphone',
  '开启语音分析上下文记忆（仅 F3 语音转文字后自动问答）': 'Activer la mémoire de contexte vocale (uniquement après transcription F3)',
  '语音上下文窗口总轮次（含当前轮）': 'Nombre total de tours de contexte vocal (tour actuel inclus)',
  '简历自动填写': 'Remplissage auto du CV',
  'F 模块页面切换': 'Changement de page du module F',
  '简历信息': 'Informations CV',
  '公司信息': 'Informations entreprises',
  '安装 Chrome 插件': 'Installer l’extension Chrome',
  '简历分区': 'Sections du CV',
  '字段名': 'Champ',
  '值': 'Valeur',
  '筛选': 'Filtrer',
  '全选当前表格公司': 'Tout sélectionner sur la page',
  '公司名': 'Entreprise',
  '公司类型': 'Type',
  '公司规模': 'Taille',
  '岗位类型': 'Type de poste',
  '投递进度': 'Progression',
  '投递日期': 'Date de candidature',
  '链接地址': 'Lien',
  '第 1 页': 'Page 1',
  '每页': 'Par page',
  '上一页': 'Page précédente',
  '下一页': 'Page suivante',
  '清空筛选': 'Réinitialiser les filtres',
  '投递选中公司': 'Postuler aux entreprises sélectionnées',
  '新增公司': 'Ajouter une entreprise',
  'Chrome 插件安装指南': 'Guide d’installation de l’extension Chrome',
  '按下面步骤把本地简历自动填写插件加载到浏览器。': 'Suivez les étapes ci-dessous pour charger l’extension locale de remplissage automatique dans le navigateur.',
  '关闭安装指南': 'Fermer le guide d’installation',
  '自动识别到的插件目录': 'Dossier détecté automatiquement',
  '复制目录': 'Copier le dossier',
  '正在识别目录...': 'Détection du dossier...',
  '如果识别失败，会在这里提示你手动检查。': 'En cas d’échec de détection, un message vous indiquera de vérifier manuellement.',
  '打开插件目录': 'Ouvrir le dossier de l’extension',
  '打开扩展页': 'Ouvrir la page des extensions',
  '我知道了': 'Compris',
  'H 测试工作台': 'H Atelier de tests',
  '当前：接口基线': 'Actuel : base API',
  '测试项': 'Élément testé',
  '停留页': 'Page mémorisée',
  '自动记住': 'Mémorisation automatique',
  'H 测试子页面切换': 'Changement de sous-page H',
  '接口基线': 'Base API',
  '语音延迟': 'Latence vocale',
  '录屏捕获': 'Capture vidéo',
  'API 基线测试': 'Test de base API',
  '测试模型': 'Modèle de test',
  '开始测试': 'Lancer le test',
  '固定题图直连当前视觉接口，只看图片问答这条链路的基础耗时。': 'Utilise une image fixe sur l’API visuelle actuelle pour mesurer uniquement la latence de la chaîne image -> réponse.',
  'API 基线测试默认题图': 'Image par défaut du test de base API',
  '最近测试': 'Tests récents',
  'F3 语音延迟测试': 'Test de latence vocale F3',
  '固定中文样本送入当前 F3 识别链路，只看语音识别本身的返回延迟。': 'Envoie un échantillon chinois fixe dans la chaîne F3 pour mesurer uniquement la latence de reconnaissance vocale.',
  '录屏捕获检测': 'Vérification de capture vidéo',
  '直接验证录屏捕获链路是否稳定拿到输出，方便复测截图与悬浮层干扰问题。': 'Vérifie directement que la chaîne de capture vidéo produit une sortie stable afin de re-tester les interférences de capture et de superposition.',
  '测试时长（秒）': 'Durée du test (s)',
  '录制帧率（FPS）': 'Fréquence d’enregistrement (FPS)',
  '打开按键焦点探针': 'Ouvrir la sonde de focus',
  '执行录屏捕获检测': 'Lancer la vérification vidéo',
  '测试输出': 'Sortie du test',
  'API管理中心': 'Centre de gestion API',
  '统一查看当前项目已接入 API、密钥状态、官方用量占位和官方管理入口。': 'Vue unifiée des API intégrées au projet, de l’état des clés, de l’usage officiel et des accès de gestion.',
  '当前为第一阶段：展示已接入 API 与密钥状态，官方用量和余额未接入时显示 `?`。': 'Phase 1 : affiche les API connectées et l’état des clés. L’usage et le solde officiels affichent `?` s’ils ne sont pas encore intégrés.',
  '已登记 API': 'API enregistrées',
  '已配置密钥数': 'Clés configurées',
  '官方读取状态': 'État de lecture officiel',
  '待接入': 'À intégrer',
  '刷新本地接入信息': 'Actualiser les intégrations locales',
  '当前接入': 'Connexion actuelle',
  '已使用': 'Utilisé',
  '剩余': 'Restant',
  '官方管理中心': 'Console officielle',
  '主题设置': 'Réglages du thème',
  '预设和色轮修改后立即生效': 'Les préréglages et couleurs s’appliquent immédiatement',
  '关闭': 'Fermer',
  '纯色': 'Uni',
  '渐变': 'Dégradé',
  '主色': 'Couleur principale',
  '副色': 'Couleur secondaire',
  '黑白': 'Noir et blanc',
  '石墨': 'Graphite',
  '极光': 'Aurore',
  '余烬': 'Braise',
  '关闭提示': 'Fermer la notification',
  '请确认': 'Veuillez confirmer',
  '取消': 'Annuler',
  '确定': 'Confirmer',
  '删除': 'Supprimer',
  '未配置': 'Non configuré',
  '豆包 / 火山引擎': 'Doubao / Volcengine',
  '讯飞': 'iFlytek',
  '进入控制台': 'Ouvrir la console',
  '讯飞语音识别 API': 'API de reconnaissance vocale iFlytek',
  '当前未识别到已登记 API。': 'Aucune API enregistrée n’a été détectée.',
  '本地默认语音识别': 'Reconnaissance vocale locale par défaut',
  '讯飞 WebSocket 语音识别': 'Reconnaissance vocale iFlytek WebSocket',
  '系统默认麦克风': 'Microphone système par défaut',
  '系统默认麦克风（当前未枚举到独立设备）': 'Microphone système par défaut (aucun périphérique distinct détecté)',
  '暂无可选项': 'Aucune option disponible',
  '请选择': 'Veuillez choisir',
  'Fields': 'Champs',
  'Prompts': 'Prompts',
  'Quick Fields': 'Champs rapides'
}));

const PATTERNS_FR = [
  [/^保存失败: (.+)$/u, "Échec de l'enregistrement : $1"],
  [/^刷新失败: (.+)$/u, 'Échec de l’actualisation : $1'],
  [/^切换失败: (.+)$/u, 'Échec du basculement : $1'],
  [/^初始化失败: (.+)$/u, 'Échec de l’initialisation : $1'],
  [/^顺序保存失败: (.+)$/u, "Échec de l'enregistrement de l’ordre : $1"],
  [/^主题保存失败: (.+)$/u, "Échec de l'enregistrement du thème : $1"],
  [/^主题面板初始化失败: (.+)$/u, "Échec de l'initialisation du panneau de thème : $1"],
  [/^麦克风列表读取失败: (.+)$/u, 'Échec de lecture de la liste des microphones : $1'],
  [/^修改目录失败: (.+)$/u, 'Échec de modification du dossier : $1'],
  [/^截图目录已更新: (.+)$/u, 'Dossier de capture mis à jour : $1'],
  [/^确认删除模板【(.+)】吗？$/u, 'Confirmer la suppression du modèle « $1 » ?'],
  [/^没有找到“(.+)”$/u, 'Aucun résultat pour « $1 »'],
  [/^内容标题已更新$/u, 'Titre du contenu mis à jour'],
  [/^内容已保存$/u, 'Contenu enregistré'],
  [/^内容已删除$/u, 'Contenu supprimé'],
  [/^已新建内容$/u, 'Nouveau contenu créé'],
  [/^已新建笔记$/u, 'Nouvelle note créée'],
  [/^已恢复到保存版本$/u, 'Version enregistrée restaurée'],
  [/^版本已保存$/u, 'Version enregistrée'],
  [/^主题已保存$/u, 'Thème enregistré'],
  [/^模块顺序已保存$/u, 'Ordre des modules enregistré'],
  [/^截图设置已保存$/u, 'Réglages de capture enregistrés'],
  [/^连接服务已启动$/u, 'Service de connexion démarré'],
  [/^连接服务已停止$/u, 'Service de connexion arrêté'],
  [/^截图完成$/u, 'Capture terminée'],
  [/^上传成功，链接已生成$/u, 'Envoi réussi, lien généré'],
  [/^存在未保存改动，确定离开吗？$/u, 'Des modifications non enregistrées existent. Voulez-vous vraiment quitter ?'],
  [/^快捷键说明：启动笔记显示悬浮窗 (.+)；目录上移 (.+)；目录下移 (.+)。在本页写入 Markdown 后会自动解析目录，点击目录或使用上下键后正文预览会自动跳转。$/u, 'Raccourcis : ouvrir la fenêtre flottante d’affichage des notes $1 ; remonter dans le plan $2 ; descendre dans le plan $3. Après saisie du Markdown sur cette page, le plan est généré automatiquement et le clic ou les touches haut/bas déplacent l’aperçu du contenu.'],
  [/^模型 ID：(.+) · 当前启用$/u, 'ID du modèle : $1 · actif'],
  [/^模型 ID：(.+)$/u, 'ID du modèle : $1'],
  [/^麦克风 (\d+)（当前系统默认）$/u, 'Microphone $1 (par défaut du système)'],
  [/^麦克风 (\d+)$/u, 'Microphone $1'],
  [/^第 (\d+) 页$/u, 'Page $1']
];

function normalizeLang(lang) {
  const value = String(lang || '').trim().toLowerCase();
  return SUPPORTED_LANGS.has(value) ? value : 'fr';
}

function translateExact(text) {
  if (currentLang !== 'fr') return text;
  return CLEAN_EXACT_FR.get(text) || EXACT_FR.get(text) || text;
}

function translatePattern(text) {
  if (currentLang !== 'fr') return text;
  for (const [regex, replacement] of PATTERNS_FR) {
    if (regex.test(text)) {
      return text.replace(regex, replacement);
    }
  }
  return text;
}

export function t(input) {
  const text = String(input ?? '');
  return translatePattern(translateExact(text));
}

if (typeof window !== 'undefined') {
  window.__appTranslate = t;
}

function shouldSkipElement(el) {
  if (!el || el.nodeType !== 1) return true;
  const tag = el.tagName;
  if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'CODE' || tag === 'PRE') return true;
  if (el.closest('textarea, [contenteditable="true"], .notes-preview-body, .notes-source-textarea')) return true;
  return false;
}

function translateTextNode(node) {
  if (!node || node.nodeType !== Node.TEXT_NODE) return;
  const raw = node.__i18nSource ?? node.nodeValue;
  node.__i18nSource = raw;
  node.nodeValue = t(raw);
}

function translateAttribute(el, attr) {
  if (!el.hasAttribute(attr)) return;
  const key = `__i18nAttr_${attr}`;
  const raw = el[key] ?? el.getAttribute(attr);
  el[key] = raw;
  el.setAttribute(attr, t(raw));
}

function translateElementText(el) {
  for (const node of Array.from(el.childNodes || [])) {
    if (node.nodeType === Node.TEXT_NODE) {
      if (!String(node.nodeValue || '').trim()) continue;
      translateTextNode(node);
    }
  }
}

export function translateTree(root = document.body) {
  if (!root) return;
  const start = root.nodeType === 1 ? root : root.parentElement;
  if (!start) return;

  if (start.nodeType === 1 && !shouldSkipElement(start)) {
    translateAttribute(start, 'placeholder');
    translateAttribute(start, 'title');
    translateAttribute(start, 'aria-label');
    translateElementText(start);
  }

  const walker = document.createTreeWalker(start, NodeFilter.SHOW_ELEMENT, {
    acceptNode(node) {
      return shouldSkipElement(node) ? NodeFilter.FILTER_SKIP : NodeFilter.FILTER_ACCEPT;
    }
  });

  let current = walker.currentNode;
  while (current) {
    translateAttribute(current, 'placeholder');
    translateAttribute(current, 'title');
    translateAttribute(current, 'aria-label');
    translateElementText(current);
    current = walker.nextNode();
  }
}

export function setLanguage(lang, options = {}) {
  currentLang = normalizeLang(lang);
  document.documentElement.lang = currentLang === 'fr' ? 'fr' : 'zh-CN';
  document.title = t('Raccourci Control Web UI');
  if (options.translateDom !== false) {
    translateTree(document.body);
  }
  return currentLang;
}

export function getLanguage() {
  return currentLang;
}

export function startAutoTranslate() {
  if (observer || !document.body) return;
  observer = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.nodeType === 1) {
          translateTree(node);
        } else if (node.nodeType === Node.TEXT_NODE && node.parentElement && !shouldSkipElement(node.parentElement)) {
          translateTextNode(node);
        }
      }
    }
  });
  observer.observe(document.body, { childList: true, subtree: true });
}


const CLEAN_EXACT_FR = new Map(Object.entries({
  'Web UI Config ? ??? ? ?? ? ??': 'Configuration Web ? style monochrome ? ombres ? animations',
  '???????????': 'Modifi?, enregistrement automatique en cours',
  '??': 'R?glages',
  '??': 'Langue',
  '??': 'Fran?ais',
  '??': '??',
  '??': 'Enregistrer',
  '?????': 'Enregistrer les raccourcis',
  '????': 'Enregistrer la note',
  '????????': 'Enregistrer le contenu affich?',
  '??????': 'Enregistrer les r?glages de capture',
  '??????': 'Enregistrer les r?glages de l?assistant',
  '??????': 'Enregistrement auto du CV',
  '?? API ??': 'Actualiser les infos API',
  '????': 'Ex?cuter le test',
  '?????': 'Th?me enregistr?',
  '?????': 'Version enregistr?e',
  '????????': 'Version enregistr?e restaur?e',
  '????': 'Fermer la notification',
  '???': 'Veuillez confirmer',
  '??': 'Annuler',
  '??': 'Confirmer',
  '??': 'Supprimer',
  '????': 'R?glages du th?me',
  '????????????': 'Les pr?r?glages et couleurs s?appliquent imm?diatement',
  '??': 'Fermer',
  '??': 'Uni',
  '??': 'D?grad?',
  '??': 'Couleur principale',
  '??': 'Couleur secondaire',
  '??': 'Noir et blanc',
  '??': 'Graphite',
  '??': 'Aurore',
  '??': 'Braise',
  '(???)': '(non d?fini)',
  '??????': 'Aucun historique',
  '??????????': 'Aucune note ? exporter',
  '??????????': 'Aucun plan ? copier',
  '?????': 'Plan copi?',
  '?????': 'Note enregistr?e',
  '?????': 'Note supprim?e',
  '???????': 'Titre de la note mis ? jour',
  '?????': 'Nouvelle note cr??e',
  '?????': 'Nouveau contenu cr??',
  '?????': 'Contenu enregistr?',
  '?????': 'Contenu supprim?',
  '???????': 'Titre du contenu mis ? jour',
  '????????????': 'Vue du contenu de la note restaur?e.',
  '???????': 'Le contenu extrait a ?t? r?inject?',
  '????????': 'Veuillez d?abord saisir le point de d?part',
  '??????': 'Veuillez d?abord cr?er une note',
  '?????????': 'Saisissez d?abord le texte ? rechercher',
  '??????????????': '?chec de l?extraction, v?rifiez la plage puis r?essayez.',
  '????????????????????????????': 'Aucun r?sultat trouv? dans la plage actuelle, le contenu principal reste inchang?.',
  '?????????...': 'Extraction du contenu des notes en cours...',
  '?????????': 'V?rification de capture vid?o termin?e',
  '?????????': 'Sonde de focus ouverte',
  '???': 'Surveillance en cours',
  '???...': 'Saisie en cours...',
  '???': 'Non s?lectionn?',
  '???': 'Non postul?',
  '???': 'Postul?',
  '????': 'Pas pour le moment',
  '??': '?chec',
  '????': 'Premier entretien pass?',
  '????': 'Deuxi?me entretien pass?',
  '??': 'Entreprise publique',
  '??': 'Entreprise priv?e',
  '??': 'Entreprise ?trang?re',
  '????': 'Stage courant',
  '????': 'Stage pr?-embauche',
  '????': 'Emploi formel',
  '?????': 'Fermer la fen?tre flottante',
  '?????': 'Afficher la fen?tre flottante',
  '?????': 'Ouvrir l?interface principale',
  '????': 'Confirmer l?insertion',
  '????': 'Monter le choix',
  '????': 'Descendre le choix',
  '???????': 'Lancer la fen?tre flottante de Q/R',
  '?????': 'Capturer puis r?pondre',
  '??????': 'Maintenir pour parler',
  '??????': 'Monter la fen?tre de Q/R',
  '??????': 'Descendre la fen?tre de Q/R',
  '??????': 'Monter dans le plan des notes',
  '??????': 'Descendre dans le plan des notes',
  '????????': 'Monter dans le plan principal',
  '????????': 'Descendre dans le plan principal',
  '?????': 'Raccourcis communs',
  '??????': 'Sp?cifique ? l?affichage des notes',
  '??????': 'Sp?cifique aux Q/R par capture',
  '??????????????? API ??????': 'Image de test fixe utilis?e pour mesurer la latence de base de l?API visuelle.',
  '?????????????????': 'La derni?re r?ponse de test s?affichera ici.',
  '???????????????????????': 'Le dernier texte reconnu du test de latence vocale s?affichera ici.'
}));

