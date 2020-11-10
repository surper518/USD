//
// Copyright 2020 Pixar
//
// Licensed under the Apache License, Version 2.0 (the "Apache License")
// with the following modification; you may not use this file except in
// compliance with the Apache License and the following modification to it:
// Section 6. Trademarks. is deleted and replaced with:
//
// 6. Trademarks. This License does not grant permission to use the trade
//    names, trademarks, service marks, or product names of the Licensor
//    and its affiliates, except as required to comply with Section 4(c) of
//    the License and to reproduce the content of the NOTICE file.
//
// You may obtain a copy of the Apache License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the Apache License with the above modification is
// distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the Apache License for the specific
// language governing permissions and limitations under the Apache License.
//

#include "shaderSection.h"

PXR_NAMESPACE_OPEN_SCOPE

HgiMetalShaderSection::~HgiMetalShaderSection() = default;

bool
HgiMetalShaderSection::VisitScopeStructs(std::ostream &ss)
{
    return false;
}

bool
HgiMetalShaderSection::VisitScopeMemberDeclarations(std::ostream &ss)
{
    return false;
}

bool
HgiMetalShaderSection::VisitScopeFunctionDefinitions(std::ostream &ss)
{
    return false;
}

bool
HgiMetalShaderSection::VisitEntryPointParameterDeclarations(std::ostream &ss)
{
    return false;
}

bool
HgiMetalShaderSection::VisitEntryPointFunctionExecutions(
    std::ostream& ss,
    const std::string &scopeInstanceName)
{
    return false;
}

HgiMetalMemberShaderSection::HgiMetalMemberShaderSection(
    const std::string &identifier,
    const std::string &type,
    const std::string &attribute,
    const std::string &attributeIndex)
  : HgiMetalShaderSection(identifier, attribute, attributeIndex)
  , _type{type}
{
}

HgiMetalMemberShaderSection::~HgiMetalMemberShaderSection() = default;

void
HgiMetalMemberShaderSection::WriteType(std::ostream &ss) const
{
    ss << _type;
}

bool
HgiMetalMemberShaderSection::VisitScopeMemberDeclarations(std::ostream &ss)
{
    WriteDeclaration(ss);
    ss << std::endl;
    return true;
}

const std::string&
HgiMetalMemberShaderSection::GetType()
{
    return _type;
}

HgiMetalSamplerShaderSection::HgiMetalSamplerShaderSection(
    const std::string &textureSharedIdentifier,
    const std::string &attribute,
    const std::string &attributeIndex)
  : HgiMetalShaderSection(
      "samplerBind_" + textureSharedIdentifier,
      attribute,
      attributeIndex)
  , _textureSharedIdentifier(textureSharedIdentifier)
{
}

void
HgiMetalSamplerShaderSection::WriteType(std::ostream& ss) const
{
    ss << "sampler";
}

bool
HgiMetalSamplerShaderSection::VisitScopeMemberDeclarations(std::ostream &ss)
{
    WriteDeclaration(ss);
    ss << std::endl;
    return true;
}

const std::string&
HgiMetalSamplerShaderSection::GetTextureSharedIdentifier()
{
    return _textureSharedIdentifier;
}

HgiMetalTextureShaderSection::HgiMetalTextureShaderSection(
    const std::string &samplerSharedIdentifier,
    const std::string &attribute,
    const std::string &attributeIndex,
    const HgiMetalSamplerShaderSection *samplerShaderSectionDependency,
    const std::string &defaultValue,
    uint32_t dimension)
  : HgiMetalShaderSection(
      "textureBind_" + samplerSharedIdentifier, 
      attribute, 
      attributeIndex, 
      defaultValue)
  , _samplerShaderSectionDependency(samplerShaderSectionDependency)
  , _dimensionsVar(dimension)
  , _samplerSharedIdentifier(samplerSharedIdentifier)
{
}

void
HgiMetalTextureShaderSection::WriteType(std::ostream& ss) const
{
    ss << "texture" << _dimensionsVar << "d<float>";
}

bool
HgiMetalTextureShaderSection::VisitScopeMemberDeclarations(std::ostream &ss)
{
    WriteDeclaration(ss);
    ss << std::endl;
    return true;
}

bool
HgiMetalTextureShaderSection::VisitScopeFunctionDefinitions(std::ostream &ss)
{
    const std::string defValue = _GetDefaultValue().empty()
        ? "0.0f"
        : _GetDefaultValue();

    ss << "#define HdGetSampler_" << _samplerSharedIdentifier
    << "() ";
    WriteIdentifier(ss);
    ss << "\n";

    ss << "vec4 HdGet_" << _samplerSharedIdentifier
       << "(vec2 coord) {\n";
    ss << "\tvec4 result = is_null_texture(";
    WriteIdentifier(ss);
    ss << ") ? "<< defValue << ": ";
    WriteIdentifier(ss);
    ss << ".sample(";
    _samplerShaderSectionDependency->WriteIdentifier(ss);
        ss << ", coord);\n";
    ss << "\treturn result;\n";
    ss << "}\n";

    ss << "vec4 HdTexelFetch_"
       << _samplerSharedIdentifier << "(ivec2 coord) {\n";
    ss << "\tvec4 result =  " << "textureBind_" << _samplerSharedIdentifier
       << ".read(ushort2(coord.x, coord.y));\n";
    ss << "\treturn result;\n";
    ss << "}\n";

    return true;
}

HgiMetalStructTypeDeclarationShaderSection::HgiMetalStructTypeDeclarationShaderSection(
    const std::string &identifier,
    const HgiMetalShaderSectionPtrVector &members)
    : HgiMetalShaderSection(identifier)
    , _members(members)
{
}

void
HgiMetalStructTypeDeclarationShaderSection::WriteType(std::ostream &ss) const
{
    ss << "struct";
}

void
HgiMetalStructTypeDeclarationShaderSection::WriteDeclaration(
    std::ostream &ss) const
{
    WriteType(ss);
    ss << " ";
    WriteIdentifier(ss);
    ss << "{\n";
    for (HgiShaderSection* member : _members) {
        if(!member->GetAttribute().empty()) {
            member->WriteAttributeWithIndex(ss);
            ss << ";\n";
        }
        else {
            member->WriteParameter(ss);
            ss << ";\n";
        }
    }
    ss << "};";
}

void
HgiMetalStructTypeDeclarationShaderSection::WriteParameter(
    std::ostream &ss) const
{
}

const HgiMetalShaderSectionPtrVector&
HgiMetalStructTypeDeclarationShaderSection::GetMembers() const
{
    return _members;
}

HgiMetalStructInstanceShaderSection::HgiMetalStructInstanceShaderSection(
    const std::string &identifier,
    const std::string &attribute,
    const std::string &attributeIndex,
    HgiMetalStructTypeDeclarationShaderSection *structTypeDeclaration,
    const std::string &defaultValue)
  : HgiMetalShaderSection (
      identifier,
      attribute,
      attributeIndex,
      defaultValue)
  , _structTypeDeclaration(structTypeDeclaration)
{
}

void
HgiMetalStructInstanceShaderSection::WriteType(std::ostream &ss) const
{
    _structTypeDeclaration->WriteIdentifier(ss);
}

const HgiMetalStructTypeDeclarationShaderSection*
HgiMetalStructInstanceShaderSection::GetStructTypeDeclaration() const
{
    return _structTypeDeclaration;
}

HgiMetalArgumentBufferInputShaderSection::HgiMetalArgumentBufferInputShaderSection(
    const std::string &identifier,
    const std::string &attribute,
    const std::string &attributeIndex,
    const std::string &addressSpace,
    const bool isPointer,
    HgiMetalStructTypeDeclarationShaderSection *structTypeDeclaration)
  : HgiMetalStructInstanceShaderSection(
      identifier,
      attribute,
      attributeIndex,
      structTypeDeclaration)
  , _addressSpace(addressSpace)
  , _isPointer(isPointer)
{
}

void
HgiMetalArgumentBufferInputShaderSection::WriteParameter(std::ostream& ss) const
{
    WriteType(ss);
    ss << " ";
    if(_isPointer) {
        ss << "*";
    }
    WriteIdentifier(ss);
}

bool
HgiMetalArgumentBufferInputShaderSection::VisitEntryPointParameterDeclarations(
    std::ostream &ss)
{
    if(!_addressSpace.empty()) {
        ss << _addressSpace << " ";
    }
    
    if(!GetAttribute().empty()) {
        WriteAttributeWithIndex(ss);
    }
    else {
        WriteParameter(ss);
    }
    return true;
}

bool
HgiMetalArgumentBufferInputShaderSection::VisitEntryPointFunctionExecutions(
    std::ostream& ss,
    const std::string &scopeInstanceName)
{
    auto structDeclMembers = GetStructTypeDeclaration()->GetMembers();
    for (auto it = structDeclMembers.begin();
         it != structDeclMembers.end();
         ++it) {
        HgiShaderSection *member = (*it);
        ss << scopeInstanceName << ".";
        member->WriteIdentifier(ss);
        ss << " = ";
        WriteIdentifier(ss);
        ss << (_isPointer ? "->" : ".");
        member->WriteIdentifier(ss);
        ss << ";";
        if(std::next(it) != structDeclMembers.end()){
            ss << "\n";
        }
    }
    return true;
}

bool
HgiMetalArgumentBufferInputShaderSection::VisitGlobalMemberDeclarations(
    std::ostream &ss)
{
    GetStructTypeDeclaration()->WriteDeclaration(ss);
    ss << "\n";
    return true;
}

HgiMetalStageOutputShaderSection::HgiMetalStageOutputShaderSection(
    const std::string &identifier,
    HgiMetalStructTypeDeclarationShaderSection *structTypeDeclaration)
  : HgiMetalStructInstanceShaderSection(
      identifier,
      std::string(),
      std::string(),
      structTypeDeclaration)
{
}

HgiMetalStageOutputShaderSection::HgiMetalStageOutputShaderSection(
    const std::string &identifier,
    const std::string &attribute,
    const std::string &attributeIndex,
    //for the time being, addressspace is just an adapter
    const std::string &addressSpace,
    const bool isPointer,
    HgiMetalStructTypeDeclarationShaderSection *structTypeDeclaration)
  : HgiMetalStructInstanceShaderSection(
      identifier,
      std::string(),
      std::string(),
      structTypeDeclaration)
{
}

bool
HgiMetalStageOutputShaderSection::VisitEntryPointFunctionExecutions(
    std::ostream& ss,
    const std::string &scopeInstanceName)
{
    ss << scopeInstanceName << ".main();\n";
    WriteDeclaration(ss);
    ss << "\n";
    auto structTypeDeclMembers = GetStructTypeDeclaration()->GetMembers();
    for (auto it = structTypeDeclMembers.begin();
         it != structTypeDeclMembers.end();
         ++it) {
        HgiMetalShaderSection *member = (*it);
        WriteIdentifier(ss);
        ss << ".";
        member->WriteIdentifier(ss);
        ss << " = " << scopeInstanceName << ".";
        member->WriteIdentifier(ss);
        ss << ";";
        if(std::next(it) != structTypeDeclMembers.end()){
            ss << "\n";
        }
    }
    return true;
}

bool
HgiMetalStageOutputShaderSection::VisitGlobalMemberDeclarations(
    std::ostream &ss)
{
    GetStructTypeDeclaration()->WriteDeclaration(ss);
    ss << "\n";
    return true;
}

bool
HgiMetalShaderSection::VisitGlobalMacros(std::ostream &ss)
{
    return false;
}

bool
HgiMetalShaderSection::VisitGlobalMemberDeclarations(std::ostream &ss)
{
    return false;
}

HgiMetalMacroShaderSection::HgiMetalMacroShaderSection(
    const std::string &macroDeclaration,
    const std::string &macroComment)
  : HgiMetalShaderSection(macroDeclaration)
  , _macroComment(macroComment)
{
}

bool
HgiMetalMacroShaderSection::VisitGlobalMacros(std::ostream &ss)
{
    WriteIdentifier(ss);
    return true;
}

PXR_NAMESPACE_CLOSE_SCOPE
