function Get-ResumeSectionDefaults {
  return @(
    [ordered]@{
      id = 'basic_info'
      title = '基本信息'
      description = '姓名、性别、联系方式、出生日期、城市等基础资料。'
      rows = @(
        [ordered]@{ id='full_name'; label='姓名'; value=''; aliases='姓名,名字,真实姓名'; type='text'; notes='' }
        ,
        [ordered]@{ id='gender'; label='性别'; value=''; aliases='性别'; type='text'; notes='' }
        ,
        [ordered]@{ id='phone'; label='手机号'; value=''; aliases='手机,电话,联系电话'; type='text'; notes='' }
        ,
        [ordered]@{ id='email'; label='邮箱'; value=''; aliases='邮箱,电子邮箱,email'; type='text'; notes='' }
        ,
        [ordered]@{ id='birth_date'; label='出生日期'; value=''; aliases='出生日期,生日'; type='text'; notes='' }
        ,
        [ordered]@{ id='current_city'; label='现居城市'; value=''; aliases='现居城市,所在城市,居住地'; type='text'; notes='' }
        ,
        [ordered]@{ id='hometown'; label='籍贯'; value=''; aliases='籍贯,户籍,生源地'; type='text'; notes='' }
        ,
        [ordered]@{ id='political_status'; label='政治面貌'; value=''; aliases='政治面貌'; type='text'; notes='' }
      )
    }
    ,
    [ordered]@{
      id = 'job_expectation'
      title = '求职期望'
      description = '目标岗位、城市、薪资、到岗时间等期望信息。'
      rows = @(
        [ordered]@{ id='target_role'; label='期望岗位'; value=''; aliases='期望岗位,应聘岗位,岗位方向'; type='text'; notes='' }
        ,
        [ordered]@{ id='target_city'; label='期望城市'; value=''; aliases='期望城市,工作城市'; type='text'; notes='' }
        ,
        [ordered]@{ id='salary'; label='期望薪资'; value=''; aliases='期望薪资,薪资要求'; type='text'; notes='' }
        ,
        [ordered]@{ id='job_type'; label='求职类型'; value=''; aliases='求职类型,全职,实习'; type='text'; notes='' }
        ,
        [ordered]@{ id='arrival_time'; label='到岗时间'; value=''; aliases='到岗时间,入职时间'; type='text'; notes='' }
      )
    }
    ,
    [ordered]@{
      id = 'education'
      title = '教育经历'
      description = '学校、专业、学历、时间、课程与成绩。'
      rows = @(
        [ordered]@{ id='school'; label='学校名称'; value=''; aliases='学校,院校,毕业院校'; type='text'; notes='' }
        ,
        [ordered]@{ id='college'; label='学院'; value=''; aliases='学院,院系'; type='text'; notes='' }
        ,
        [ordered]@{ id='major'; label='专业'; value=''; aliases='专业'; type='text'; notes='' }
        ,
        [ordered]@{ id='degree'; label='学历'; value=''; aliases='学历'; type='text'; notes='' }
        ,
        [ordered]@{ id='education_time'; label='就读时间'; value=''; aliases='在校时间,起止时间,教育时间'; type='text'; notes='' }
        ,
        [ordered]@{ id='gpa_rank'; label='GPA/排名'; value=''; aliases='GPA,排名,绩点'; type='text'; notes='' }
        ,
        [ordered]@{ id='courses'; label='主修课程'; value=''; aliases='主修课程,核心课程'; type='textarea'; notes='' }
      )
    }
    ,
    [ordered]@{
      id = 'internship'
      title = '实习经历'
      description = '实习单位、岗位、时间和工作内容。'
      rows = @(
        [ordered]@{ id='intern_company'; label='实习单位'; value=''; aliases='公司,实习单位,单位名称'; type='text'; notes='' }
        ,
        [ordered]@{ id='intern_role'; label='实习岗位'; value=''; aliases='岗位,职位,担任职务'; type='text'; notes='' }
        ,
        [ordered]@{ id='intern_time'; label='实习时间'; value=''; aliases='实习时间,起止时间'; type='text'; notes='' }
        ,
        [ordered]@{ id='intern_desc'; label='实习内容'; value=''; aliases='工作内容,职责描述,实习描述'; type='textarea'; notes='' }
      )
    }
    ,
    [ordered]@{
      id = 'project'
      title = '项目经历'
      description = '项目名称、角色、时间与项目亮点。'
      rows = @(
        [ordered]@{ id='project_name'; label='项目名称'; value=''; aliases='项目名称'; type='text'; notes='' }
        ,
        [ordered]@{ id='project_role'; label='项目角色'; value=''; aliases='项目角色,职责'; type='text'; notes='' }
        ,
        [ordered]@{ id='project_time'; label='项目时间'; value=''; aliases='项目时间,起止时间'; type='text'; notes='' }
        ,
        [ordered]@{ id='project_desc'; label='项目描述'; value=''; aliases='项目描述,项目内容,项目亮点'; type='textarea'; notes='' }
      )
    }
    ,
    [ordered]@{
      id = 'campus_position'
      title = '在校职务'
      description = '学生组织、班级或社团中的职务与职责。'
      rows = @(
        [ordered]@{ id='position_org'; label='组织/部门'; value=''; aliases='组织,部门,班级'; type='text'; notes='' }
        ,
        [ordered]@{ id='position_name'; label='职务'; value=''; aliases='职务,职位'; type='text'; notes='' }
        ,
        [ordered]@{ id='position_time'; label='任职时间'; value=''; aliases='任职时间,起止时间'; type='text'; notes='' }
        ,
        [ordered]@{ id='position_desc'; label='工作内容'; value=''; aliases='工作内容,职责描述'; type='textarea'; notes='' }
      )
    }
    ,
    [ordered]@{
      id = 'campus_activity'
      title = '校园活动'
      description = '比赛、活动、志愿服务等经历。'
      rows = @(
        [ordered]@{ id='activity_name'; label='活动名称'; value=''; aliases='活动名称,赛事名称'; type='text'; notes='' }
        ,
        [ordered]@{ id='activity_role'; label='担任角色'; value=''; aliases='角色,分工'; type='text'; notes='' }
        ,
        [ordered]@{ id='activity_time'; label='活动时间'; value=''; aliases='活动时间'; type='text'; notes='' }
        ,
        [ordered]@{ id='activity_desc'; label='活动描述'; value=''; aliases='活动描述,活动内容'; type='textarea'; notes='' }
      )
    }
    ,
    [ordered]@{
      id = 'family'
      title = '家庭成员'
      description = '家庭成员相关补充信息。'
      rows = @(
        [ordered]@{ id='family_info'; label='家庭成员情况'; value=''; aliases='家庭成员,家庭情况'; type='textarea'; notes='' }
      )
    }
    ,
    [ordered]@{
      id = 'awards'
      title = '获奖经历'
      description = '奖项、时间、级别及说明。'
      rows = @(
        [ordered]@{ id='award_name'; label='奖项名称'; value=''; aliases='奖项名称,荣誉名称'; type='text'; notes='' }
        ,
        [ordered]@{ id='award_time'; label='获奖时间'; value=''; aliases='获奖时间'; type='text'; notes='' }
        ,
        [ordered]@{ id='award_level'; label='奖项级别'; value=''; aliases='奖项级别,奖项等级'; type='text'; notes='' }
        ,
        [ordered]@{ id='award_desc'; label='奖项说明'; value=''; aliases='奖项说明,奖项描述'; type='textarea'; notes='' }
      )
    }
    ,
    [ordered]@{
      id = 'english'
      title = '英语能力'
      description = '等级成绩与语言能力补充说明。'
      rows = @(
        [ordered]@{ id='english_level'; label='英语等级'; value=''; aliases='英语等级'; type='text'; notes='' }
        ,
        [ordered]@{ id='cet4'; label='CET4'; value=''; aliases='四级,CET4'; type='text'; notes='' }
        ,
        [ordered]@{ id='cet6'; label='CET6'; value=''; aliases='六级,CET6'; type='text'; notes='' }
        ,
        [ordered]@{ id='ielts'; label='IELTS'; value=''; aliases='雅思,IELTS'; type='text'; notes='' }
        ,
        [ordered]@{ id='toefl'; label='TOEFL'; value=''; aliases='托福,TOEFL'; type='text'; notes='' }
        ,
        [ordered]@{ id='english_desc'; label='英语说明'; value=''; aliases='英语说明,语言能力'; type='textarea'; notes='' }
      )
    }
    ,
    [ordered]@{
      id = 'certificates'
      title = '证书信息'
      description = '资格证书、时间与补充说明。'
      rows = @(
        [ordered]@{ id='certificate_name'; label='证书名称'; value=''; aliases='证书名称,证书'; type='text'; notes='' }
        ,
        [ordered]@{ id='certificate_time'; label='获取时间'; value=''; aliases='获取时间,发证时间'; type='text'; notes='' }
        ,
        [ordered]@{ id='certificate_no'; label='证书编号'; value=''; aliases='证书编号'; type='text'; notes='' }
        ,
        [ordered]@{ id='certificate_desc'; label='证书说明'; value=''; aliases='证书说明'; type='textarea'; notes='' }
      )
    }
    ,
    [ordered]@{
      id = 'self_intro'
      title = '自我介绍'
      description = '用于招聘系统中的长文本自我介绍。'
      rows = @(
        [ordered]@{ id='self_intro'; label='自我介绍'; value=''; aliases='自我介绍,个人总结,个人优势'; type='textarea'; notes='' }
      )
    }
  )
}

function New-ResumeProfileDefault {
  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  return [ordered]@{
    version = 1
    updated_at = $ts
    sections = (Get-ResumeSectionDefaults)
  }
}

function Ensure-ResumeProfileFile {
  if ([string]::IsNullOrWhiteSpace([string]$ResumeProfileFile)) {
    throw 'ResumeProfileFile not configured'
  }
  $dir = Split-Path -Parent $ResumeProfileFile
  if (-not [string]::IsNullOrWhiteSpace($dir)) {
    Ensure-Dir $dir
  }
  if (-not (Test-Path $ResumeProfileFile)) {
    $defaultProfile = New-ResumeProfileDefault
    [IO.File]::WriteAllText($ResumeProfileFile, (To-JsonNoBom $defaultProfile 20), [Text.Encoding]::UTF8)
  }
}

function Normalize-ResumeRow {
  param($Row, [int]$Index = 0)

  $label = ([string](Get-Prop $Row 'label' '')).Trim()
  if ($label -eq '') {
    $label = '字段' + ($Index + 1)
  }

  $id = ([string](Get-Prop $Row 'id' '')).Trim()
  if ($id -eq '') {
    $id = ('field_' + ($Index + 1))
  }

  $type = ([string](Get-Prop $Row 'type' 'text')).Trim().ToLowerInvariant()
  if ($type -notin @('text', 'textarea', 'select', 'date')) {
    $type = 'text'
  }

  return [ordered]@{
    id = $id
    label = $label
    value = [string](Get-Prop $Row 'value' '')
    aliases = [string](Get-Prop $Row 'aliases' '')
    type = $type
    notes = [string](Get-Prop $Row 'notes' '')
  }
}

function Normalize-ResumeSection {
  param($Section, [int]$Index = 0)

  $id = ([string](Get-Prop $Section 'id' '')).Trim()
  if ($id -eq '') {
    $id = ('section_' + ($Index + 1))
  }
  $title = ([string](Get-Prop $Section 'title' '')).Trim()
  if ($title -eq '') {
    $title = '分区' + ($Index + 1)
  }

  $rowsOut = @()
  $i = 0
  foreach ($row in @(Get-Prop $Section 'rows' @())) {
    $rowsOut += Normalize-ResumeRow -Row $row -Index $i
    $i += 1
  }

  return [ordered]@{
    id = $id
    title = $title
    description = [string](Get-Prop $Section 'description' '')
    rows = $rowsOut
  }
}

function Normalize-ResumeProfile {
  param($Profile)

  $defaults = New-ResumeProfileDefault
  $incomingSections = @()
  $idx = 0
  foreach ($section in @(Get-Prop $Profile 'sections' @())) {
    $incomingSections += Normalize-ResumeSection -Section $section -Index $idx
    $idx += 1
  }

  if (-not $incomingSections.Count) {
    $incomingSections = $defaults.sections
  }

  return [ordered]@{
    version = 1
    updated_at = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    sections = $incomingSections
  }
}

function Get-ResumeProfile {
  Ensure-ResumeProfileFile
  try {
    $raw = [IO.File]::ReadAllText($ResumeProfileFile, [Text.Encoding]::UTF8)
    if ([string]::IsNullOrWhiteSpace($raw)) {
      return New-ResumeProfileDefault
    }
    return Normalize-ResumeProfile -Profile ($raw | ConvertFrom-Json)
  }
  catch {
    return New-ResumeProfileDefault
  }
}

function Get-ResumeFlatMap {
  param($Profile)

  $map = [ordered]@{}
  foreach ($section in @(Get-Prop $Profile 'sections' @())) {
    foreach ($row in @(Get-Prop $section 'rows' @())) {
      $label = ([string](Get-Prop $row 'label' '')).Trim()
      $value = [string](Get-Prop $row 'value' '')
      if ($label -eq '' -or $value -eq '') { continue }

      $map[$label] = $value
      $id = ([string](Get-Prop $row 'id' '')).Trim()
      if ($id -ne '') {
        $map[$id] = $value
      }

      $aliases = [string](Get-Prop $row 'aliases' '')
      foreach ($alias in ($aliases -split ',')) {
        $name = $alias.Trim()
        if ($name -eq '') { continue }
        $map[$name] = $value
      }
    }
  }
  return $map
}

function Get-ResumeState {
  $profile = Get-ResumeProfile
  return [ordered]@{
    profile = $profile
    flat_map = (Get-ResumeFlatMap -Profile $profile)
  }
}

function Save-ResumeProfile {
  param($Payload)

  Ensure-ResumeProfileFile
  $source = Get-Prop $Payload 'profile' $Payload
  $profile = Normalize-ResumeProfile -Profile $source
  [IO.File]::WriteAllText($ResumeProfileFile, (To-JsonNoBom $profile 20), [Text.Encoding]::UTF8)
  Write-AppLog 'resume_profile_save' ('sections=' + @($profile.sections).Count)
  return (Get-ResumeState)
}
